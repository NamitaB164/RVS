import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report, accuracy_score
from sklearn.preprocessing import LabelEncoder
import joblib
import os

# Load dataset
df = pd.read_csv("seismo_rvs_dataset.csv")

# Encode categorical features
le_material = LabelEncoder()
df["building_material"] = le_material.fit_transform(df["building_material"])

# Encode the risk column (target variable) - it's named 'risk' not 'risk_rating'
le_risk = LabelEncoder()
df["risk"] = le_risk.fit_transform(df["risk"])

# Save the encoders for prediction use
os.makedirs("model", exist_ok=True)
joblib.dump(le_material, "model/material_encoder.pkl")
joblib.dump(le_risk, "model/risk_encoder.pkl")

# Convert boolean to int for soft_story
df["soft_story"] = df["soft_story"].astype(int)

# Features and label
X = df.drop(columns=["risk"])  
y = df["risk"]

# Split
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

# Model
clf = RandomForestClassifier(n_estimators=100, random_state=42)
clf.fit(X_train, y_train)

# Evaluate
y_pred = clf.predict(X_test)
print("Accuracy:", accuracy_score(y_test, y_pred))
print("Classification Report:\n", classification_report(y_test, y_pred, target_names=le_risk.classes_))

# Save model
joblib.dump(clf, "model/random_forest_model.pkl")


print("✅ Model saved to model/random_forest_model.pkl")