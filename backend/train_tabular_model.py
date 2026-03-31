import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report, accuracy_score, f1_score
from xgboost import XGBClassifier
from sklearn.preprocessing import LabelEncoder
import joblib
import json
import os

def smooth_target_encode(series, target, m=10):
    """
    Computes smoothed target encoding for a categorical column.
    """
    global_mean = target.mean()
    agg = target.groupby(series).agg(['count', 'mean'])
    counts = agg['count']
    means = agg['mean']
    
    # Smoothing formula: (n * mean + m * global_mean) / (n + m)
    smooth = (counts * means + m * global_mean) / (counts + m)
    
    return series.map(smooth).fillna(global_mean), smooth, global_mean

def main():
    print("Starting Advanced Model Improvement Pipeline...")
    
    # Load the DrivenData CSVs
    values_path = "../train_values.csv"
    labels_path = "../train_labels.csv"
    
    if not os.path.exists(values_path) or not os.path.exists(labels_path):
        print(f"❌ Error: Make sure {values_path} and {labels_path} exist.")
        return

    # 1. Load and Merge
    print("Loading datasets...")
    X_full = pd.read_csv(values_path)
    y_full = pd.read_csv(labels_path)
    df = pd.merge(X_full, y_full, on="building_id")
    df = df.drop(columns=["building_id"])
    
    # 2. Define Features
    # We stick to the Top 10 for RVS efficiency
    top_10_features = [
        "geo_level_3_id", "geo_level_1_id", "geo_level_2_id", 
        "age", "area_percentage", "height_percentage", 
        "roof_type", "count_families", "foundation_type", "position"
    ]
    
    X = df[top_10_features].copy()
    y = df["damage_grade"]
    
    # 3. Label Encode non-geo categorical features
    categorical_cols = ["roof_type", "foundation_type", "position"]
    encoders = {}
    for col in categorical_cols:
        le = LabelEncoder()
        X[col] = le.fit_transform(X[col].fillna("Unknown"))
    # --- SMARTER BALANCING: UNDER-SAMPLING ---
    # To reduce the bias towards 'Grade 2' (Restricted), we will sample all classes down to the size of the smallest class.
    print("Balancing dataset via under-sampling...")
    class_counts = df['damage_grade'].value_counts()
    min_size = class_counts.min()
    print(f"Sampling each class down to {min_size} rows (Smallest class size).")

    balanced_df = pd.concat([
        df[df['damage_grade'] == label].sample(min_size, random_state=42)
        for label in class_counts.index
    ])
    
    # Use the balanced data for the rest of the pipeline
    X = balanced_df[top_10_features]
    y_raw = balanced_df['damage_grade']
    
    # Re-map target to 0, 1, 2
    le_target = LabelEncoder()
    y = le_target.fit_transform(y_raw)

    print(f"Final training set size: {len(X)}")

    # Split
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42, stratify=y)
    # --- END BALANCING ---

    # 1. Target Encoding (using the 0-2 target scale now for better calibration)
    target_encode_cols = ["geo_level_1_id", "geo_level_2_id", "geo_level_3_id"]
    target_encoders = {}
    
    X_train_encoded = X_train.copy()
    X_test_encoded = X_test.copy()
    
    for col in target_encode_cols:
        # We now use y_train (0, 1, 2) as the target for the mean calculation
        X_train_encoded[col], mapping, global_avg = smooth_target_encode(X_train[col], pd.Series(y_train, index=X_train.index), m=10)
        X_test_encoded[col] = X_test[col].map(mapping).fillna(global_avg)
        
        target_encoders[col] = {
            "mapping": mapping.to_dict(),
            "global_avg": global_avg
        }

    # 2. Label Encoding (Categorical to Numeric)
    categorical_encoders = {}
    for col in ["roof_type", "foundation_type", "position"]:
        le = LabelEncoder()
        X_train_encoded[col] = le.fit_transform(X_train[col])
        X_test_encoded[col] = X_test[col].map(lambda s: le.transform([s])[0] if s in le.classes_ else 0)
        categorical_encoders[col] = le

    # 3. Model Training (Balanced XGBoost)
    print("Training Balanced XGBoost Classifier...")
    model = XGBClassifier(
        n_estimators=1000,
        max_depth=8,
        learning_rate=0.05,
        subsample=0.8,
        colsample_bytree=0.8,
        objective='multi:softprob',
        num_class=3,
        random_state=42,
        early_stopping_rounds=50,
        tree_method='hist'
    )

    model.fit(
        X_train_encoded, y_train,
        eval_set=[(X_test_encoded, y_test)],
        verbose=100
    )
    
    # 6. Evaluation
    y_pred = model.predict(X_test_encoded)
    accuracy = accuracy_score(y_test, y_pred)
    micro_f1 = f1_score(y_test, y_pred, average='micro')
    
    print(f"\n--- Model Improvement Results ---")
    print(f"Accuracy: {accuracy:.4f}")
    print(f"Micro F1 Score: {micro_f1:.4f}")
    print("\nClassification Report:")
    print(classification_report(y_test_xgb, y_pred, target_names=["Low", "Medium", "High"]))

    # 7. Save Assets
    print("\nSaving improved artifacts to backend/model/...")
    os.makedirs("model", exist_ok=True)
    
    # Save the model
    joblib.dump(xgb_model, "model/rvs_top10_xgb_model.pkl")
    
    # Save all encoders
    joblib.dump(encoders, "model/categorical_encoders.pkl")
    joblib.dump(target_encoders, "model/target_encoders.pkl")
    
    # Save metadata
    with open("model/top_10_features.json", "w") as f:
        json.dump(top_10_features, f)
        
    # Save classification report
    report = classification_report(y_test_xgb, y_pred, output_dict=True)
    with open("model/classification_report.json", "w") as f:
        json.dump(report, f, indent=2)

    print("Model improvement complete! All systems updated.")

if __name__ == "__main__":
    main()
