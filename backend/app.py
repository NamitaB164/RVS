from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import joblib
import pandas as pd
import numpy as np
import os
import json

# 1. Load model and artifacts
# Use absolute paths for serverless deployment
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_DIR = os.path.join(BASE_DIR, "model")

model = joblib.load(os.path.join(MODEL_DIR, "rvs_top10_xgb_model.pkl"))
categorical_encoders = joblib.load(os.path.join(MODEL_DIR, "categorical_encoders.pkl"))
target_encoders = joblib.load(os.path.join(MODEL_DIR, "target_encoders.pkl"))

# Load feature order
with open(os.path.join(MODEL_DIR, "top_10_features.json"), "r") as f:
    top_10_features = json.load(f)

app = FastAPI()

# CORS setup for Flutter Web/Mobile
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class BuildingData(BaseModel):
    geo_level_1_id: int
    geo_level_2_id: int
    geo_level_3_id: int
    age: int
    area_percentage: int
    height_percentage: int
    roof_type: str
    count_families: int
    foundation_type: str
    position: str

def map_damage_to_fema(grade: int):
    """
    Maps 1, 2, 3 damage grades to FEMA risk tags and colors.
    """
    if grade == 1:
        return "SAFE", "green"
    elif grade == 2:
        return "RESTRICTED", "yellow"
    else:
        return "UNSAFE", "red"

@app.post("/analyze")
async def analyze_building(data: BuildingData):
    try:
        # Convert input to DataFrame for processing
        input_dict = data.dict()
        df = pd.DataFrame([input_dict])

        # 1. Apply Label Encoding for categorical fields
        for col, le in categorical_encoders.items():
            if col in df.columns:
                # Handle unknown labels gracefully
                df[col] = df[col].map(lambda s: le.transform([s])[0] if s in le.classes_ else 0)

        # 2. Apply Target Encoding for Geo IDs
        for col, meta in target_encoders.items():
            if col in df.columns:
                mapping = meta["mapping"]
                global_avg = meta["global_avg"]
                # Map the ID to its mean damage grade; use global average if ID is new
                df[col] = df[col].map(mapping).fillna(global_avg)

        # 3. Reorder columns to match the model training order
        df = df[top_10_features]

        # 4. Predict
        # XGBoost output is 0, 1, 2 -> map to 1, 2, 3
        prediction_idx = model.predict(df)[0]
        damage_grade = int(prediction_idx) + 1
        
        fema_tag, color = map_damage_to_fema(damage_grade)

        return {
            "damage_grade": damage_grade,
            "fema_tag": fema_tag,
            "color": color,
            "success": True
        }

    except Exception as e:
        print(f"Error during prediction: {e}")
        return {"error": str(e), "success": False}

@app.get("/")
def health_check():
    return {"status": "Structura AI Backend is Online"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
