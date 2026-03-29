import os
from fastapi import FastAPI, File, UploadFile
from fastapi.responses import JSONResponse
import numpy as np
import tensorflow as tf
from PIL import Image
import io

app = FastAPI(title="RVS Building Damage Classifier API")

# Define FEMA classes mapped exactly from our Colab model script
CLASSES = ['safe', 'restricted', 'unsafe']

# Initialize the model as a global
model = None
MODEL_PATH = "rvs_fema_model.keras" # Should be uploaded here after training in Colab

@app.on_event("startup")
def load_model():
    global model
    if os.path.exists(MODEL_PATH):
        try:
            print("Loading Keras Model...")
            model = tf.keras.models.load_model(MODEL_PATH)
            print("Model loaded successfully!")
        except Exception as e:
            print(f"Error loading model: {str(e)}")
    else:
        print(f"WARNING: Model file {MODEL_PATH} not found. API will return mock predictions until you upload it.")


@app.get("/")
def read_root():
    return {"message": "RVS Model API is running!", "status": "Ready"}


@app.post("/predict")
async def predict_damage(file: UploadFile = File(...)):
    """
    Receives an uploaded building image, runs it through the EfficientNet Keras model,
    and returns the predicted FEMA tag.
    """
    try:
        # Read the image bytes
        contents = await file.read()
        image = Image.open(io.BytesIO(contents)).convert('RGB')
        
        # Preprocess the image to match our model's input size (224x224)
        image = image.resize((224, 224))
        img_array = np.array(image) / 255.0 # Rescale 1./255 as in our Colab script
        img_array = np.expand_dims(img_array, axis=0) # Add batch dimension
        
        # Check if the real model has been uploaded yet
        if model is None:
            # Random mock prediction if model missing
            import random
            pred_class = random.choice(CLASSES)
            confidence = round(random.uniform(0.7, 0.99), 2)
        else:
            # Run real model prediction
            predictions = model.predict(img_array)
            pred_idx = np.argmax(predictions[0])
            pred_class = CLASSES[pred_idx]
            confidence = round(float(np.max(predictions[0])), 2)
            
        # Format the FEMA output for safety UI
        fema_tag = "Safe"
        color = "green"
        if pred_class == "restricted":
            fema_tag = "Restricted"
            color = "yellow"
        elif pred_class == "unsafe":
            fema_tag = "Unsafe"
            color = "red"
            
        return JSONResponse(status_code=200, content={
            "fema_tag": fema_tag,
            "color": color,
            "raw_class": pred_class,
            "confidence": confidence
        })
        
    except Exception as e:
        return JSONResponse(status_code=500, content={"error": str(e)})

# To run locally: uvicorn main:app --reload
