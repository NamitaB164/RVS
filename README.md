# Rapid Visual Screening (RVS) Earthquake Risk Predictor

Rapid Visual Screening (RVS) is a preliminary method for quickly evaluating the vulnerability of buildings to seismic hazards without performing an in-depth structural analysis. It leverages visual and architectural characteristics—such as construction material, number of stories, and structural irregularities—to estimate risk levels.

This project uses RVS principles in combination with machine learning to predict the seismic risk of buildings based on user-input parameters.

---

## How It Works

1. **Data Collection**: A CSV dataset (`seismo_rvs_dataset.csv`) containing structural details and risk ratings is used to train the model.
2. **Training**: A Random Forest Classifier is trained (`trainmodel.py`) on encoded structural features.
3. **Model Deployment**: The trained model and label encoders are served using a FastAPI backend (`app.py`).
4. **Prediction**: Users submit building details via an API and receive predicted seismic risk levels.
5. **Database Support**: SQLAlchemy models (`models.py`, `db.py`) are used for optional persistence of predictions.


