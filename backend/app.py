from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import joblib
import pandas as pd

# Load model and encoders
model = joblib.load("model/random_forest_model.pkl")
material_encoder = joblib.load("model/material_encoder.pkl")
risk_encoder = joblib.load("model/risk_encoder.pkl")

app = FastAPI()

# CORS setup
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class BuildingData(BaseModel):
    year_built: int
    stories: int
    building_material: str
    height: int
    irregularities: bool
    latitude: float
    longitude: float
    soft_story: bool

@app.post("/enter_rvs")
async def enter_rvs(data: BuildingData):
    print(f"Received RVS Submission:\n{data}")
    return {
        "message": "Data received successfully!",
        "data": data
    }

@app.post("/predict_risk")
async def predict_risk(data: BuildingData):
    try:
        material_encoded = material_encoder.transform([data.building_material])[0]

        input_df = pd.DataFrame([{
            "year_built": data.year_built,
            "stories": data.stories,
            "building_material": material_encoded,
            "height": data.height,
            "irregularities": int(data.irregularities),
            "latitude": data.latitude,
            "longitude": data.longitude,
            "soft_story": int(data.soft_story),
        }])

        prediction = model.predict(input_df)[0]
        predicted_label = risk_encoder.inverse_transform([prediction])[0]

        return {
            "building": data,
            "predicted_risk": predicted_label
        }

    except Exception as e:
        print("Exception during prediction:", e)
        return {"error": str(e)}

@app.get("/prediction_history")
def get_predictions():
    # Dummy history endpoint
    return {
        "message": "Prediction history is disabled in this version (no database)."
    }
