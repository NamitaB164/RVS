# models.py
from sqlalchemy import Column, Integer, String, Float, Boolean, DateTime
from sqlalchemy.sql import func
from db import Base

class Prediction(Base):
    __tablename__ = "predictions"

    id = Column(Integer, primary_key=True, index=True)
    year_built = Column(Integer)
    stories = Column(Integer)
    building_material = Column(String)
    height = Column(Integer)
    irregularities = Column(Boolean)
    latitude = Column(Float)
    longitude = Column(Float)
    soft_story = Column(Boolean)
    predicted_risk = Column(String)
    timestamp = Column(DateTime(timezone=True), server_default=func.now())
