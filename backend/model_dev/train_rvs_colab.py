import os
import tarfile
import json
import numpy as np
import tensorflow as tf
from tensorflow.keras.preprocessing.image import ImageDataGenerator
from tensorflow.keras.applications import EfficientNetB0
from tensorflow.keras import layers, models
from PIL import Image

# ==========================================
# 1. SETUP & CONFIGURATION
# ==========================================
# Run this entire script in Google Colab (upload it or copy-paste into cells)

# Path to your uploaded tar.gz files in Colab
TRAIN_TAR = 'train_images_labels_targets.tar.gz'
TEST_TAR = 'test_images_labels_targets.tar.gz'

# Extracted paths
DATA_DIR = './dataset'
TRAIN_DIR = os.path.join(DATA_DIR, 'train')
TEST_DIR = os.path.join(DATA_DIR, 'test')

# Organized Cropped Output Paths (For FEMA classification)
# We will sort images into these folders so Keras `flow_from_directory` can read them.
CROPPED_DIR = './cropped_dataset'
CLASSES = ['safe', 'restricted', 'unsafe']

def extract_tar(tar_path, output_path):
    print(f"Extracting {tar_path}...")
    if not os.path.exists(tar_path):
        print(f"File {tar_path} not found. Make sure you've uploaded it to Colab.")
        return
    with tarfile.open(tar_path, 'r:gz') as tar:
        tar.extractall(path=output_path)
    print("Done extracting.")

# Uncomment these if running from scratch:
# extract_tar(TRAIN_TAR, DATA_DIR)
# extract_tar(TEST_TAR, DATA_DIR)

# ==========================================
# 2. DATA PREPROCESSING (Cropping & FEMA Mapping)
# ==========================================
def map_xbd_to_fema(damage_level):
    """
    Maps xBD damage states to our 3 FEMA tags.
    Adjust this logic as needed for your specific criteria!
    """
    if damage_level in ['no-damage']:
        return 'safe'
    elif damage_level in ['minor-damage']:
        return 'restricted'
    elif damage_level in ['major-damage', 'destroyed']:
        return 'unsafe'
    return None # Ignore un-classified or background

def process_and_crop(split='train'):
    """
    Reads the xBD JSON labels, crops out the polygon bounds for each building,
    and saves them in the appropriate FEMA folder (safe/restricted/unsafe).
    """
    split_path = os.path.join(DATA_DIR, split) # e.g. ./dataset/train
    images_dir = os.path.join(split_path, 'images')
    labels_dir = os.path.join(split_path, 'labels')
    
    if not os.path.exists(images_dir):
        print(f"Skipping crop for {split}, directory not found.")
        return

    # Create sub-folders
    for c in CLASSES:
        os.makedirs(os.path.join(CROPPED_DIR, split, c), exist_ok=True)
        
    print(f"Processing crops for {split}...")
    json_files = [f for f in os.listdir(labels_dir) if f.endswith('.json')]
    
    for count, jf in enumerate(json_files):
        with open(os.path.join(labels_dir, jf), 'r') as f:
            data = json.load(f)
            
        # Get the corresponding image
        image_name = data['metadata']['img_name']
        image_path = os.path.join(images_dir, image_name)
        
        if not os.path.exists(image_path):
            continue
            
        try:
            img = Image.open(image_path)
        except Exception as e:
            continue
            
        # Extract buildings
        for obj in data['features']['xy']:
            props = obj['properties']
            if 'feature_type' in props and props['feature_type'] == 'building':
                subtype = props.get('subtype', 'un-classified')
                fema_tag = map_xbd_to_fema(subtype)
                
                if not fema_tag:
                    continue # Skip unclassified
                
                # Get bounding box coordinates from WKT polygon string
                # xBD polygons look like: POLYGON ((x1 y1, x2 y2, ...))
                # We need simple (min_x, min_y, max_x, max_y) to crop the building
                poly_wkt = obj['wkt']
                poly_pts = poly_wkt.replace("POLYGON ((", "").replace("))", "").split(", ")
                coords = [list(map(float, pt.split(" "))) for pt in poly_pts]
                
                xs = [c[0] for c in coords]
                ys = [c[1] for c in coords]
                bbox = (int(min(xs)), int(min(ys)), int(max(xs)), int(max(ys)))
                
                # Expand box slightly to retain context
                pad = 10
                bbox = (max(0, bbox[0]-pad), max(0, bbox[1]-pad), 
                        min(img.width, bbox[2]+pad), min(img.height, bbox[3]+pad))
                
                # Crop and save
                # We use the unique building ID to name the crop
                uid = props.get('uid', 'unknown')
                crop = img.crop(bbox)
                
                # Only save if crop is larger than 10x10 pixels (to filter out tiny debris)
                if crop.width > 10 and crop.height > 10:
                    save_path = os.path.join(CROPPED_DIR, split, fema_tag, f"{image_name}_{uid}.jpg")
                    crop.save(save_path)
                    
        if count % 100 == 0:
            print(f"Processed {count} / {len(json_files)} images...")

# Uncomment these when ready to crop images:
# process_and_crop('train')
# process_and_crop('test')

# ==========================================
# 3. KERAS MODEL TRAINING
# ==========================================
def train_model():
    print("Setting up model and data loaders...")
    
    IMG_SIZE = 224 # Standard size for EfficientNet
    BATCH_SIZE = 32
    
    # 1. Image Generators (With Data Augmentation for Train)
    train_datagen = ImageDataGenerator(
        rescale=1./255,
        rotation_range=20,
        width_shift_range=0.2,
        height_shift_range=0.2,
        horizontal_flip=True,
        fill_mode='nearest'
    )
    
    val_datagen = ImageDataGenerator(rescale=1./255)
    
    train_generator = train_datagen.flow_from_directory(
        os.path.join(CROPPED_DIR, 'train'),
        target_size=(IMG_SIZE, IMG_SIZE),
        batch_size=BATCH_SIZE,
        class_mode='categorical' # 3 classes
    )
    
    val_generator = val_datagen.flow_from_directory(
        os.path.join(CROPPED_DIR, 'test'), # Use our test data as validation
        target_size=(IMG_SIZE, IMG_SIZE),
        batch_size=BATCH_SIZE,
        class_mode='categorical'
    )

    # 2. Build EfficientNet Model architecture
    # We use weights='imagenet' to use transfer learning!
    base_model = EfficientNetB0(weights='imagenet', include_top=False, input_shape=(IMG_SIZE, IMG_SIZE, 3))
    
    # Freeze the base so we don't destroy pre-trained features immediately
    base_model.trainable = False 
    
    # Add custom classification head on top
    model = models.Sequential([
        base_model,
        layers.GlobalAveragePooling2D(),
        layers.Dropout(0.3),
        layers.Dense(256, activation='relu'),
        layers.Dense(3, activation='softmax') # 3 outputs (Safe, Restricted, Unsafe)
    ])
    
    model.compile(
        optimizer='adam', 
        loss='categorical_crossentropy', 
        metrics=['accuracy']
    )
    
    print("\nStarting Training Phase 1 (Heads only)...")
    history1 = model.fit(
        train_generator,
        epochs=10, 
        validation_data=val_generator
    )
    
    # Optional: Fine-Tuning Phase (unfreeze base layers to improve accuracy)
    print("\nStarting Fine-tuning Phase 2 (Unfreezing base model)...")
    base_model.trainable = True
    # Recompile with very low learning rate
    model.compile(optimizer=tf.keras.optimizers.Adam(learning_rate=1e-5), 
                  loss='categorical_crossentropy', 
                  metrics=['accuracy'])
                  
    history2 = model.fit(
        train_generator,
        epochs=10, 
        validation_data=val_generator
    )
    
    # 3. Save Model for FastAPI Deployment
    model.save('rvs_fema_model.keras')
    print("Model saved to rvs_fema_model.keras")

# Uncomment to start training once crops are ready
# train_model()
