import pandas as pd
import matplotlib.pyplot as plt
from sklearn.cluster import KMeans
import numpy as np
import pickle
from flask import Flask, jsonify, request

df = pd.read_csv("D:/Darshan Studies/Projects/hackathon/women-safety/lib/models/crime_dataset_1000.csv")


dangerous_areas = df.groupby(["City", "Area", "Latitude", "Longitude"])['Crime Frequency'].sum().reset_index()


dangerous_areas = dangerous_areas.sort_values(by='Crime Frequency', ascending=False)


num_clusters = 3  # Low, Medium, High risk
kmeans = KMeans(n_clusters=num_clusters, random_state=42)
dangerous_areas['Risk Level'] = kmeans.fit_predict(dangerous_areas[['Crime Frequency']])

dangerous_areas['Risk Level'] = dangerous_areas['Risk Level'].map({0: 'Low', 1: 'Medium', 2: 'High'})

with open("kmeans_model.pkl", "wb") as model_file:
    pickle.dump(kmeans, model_file)

# Predict risk level for each city by averaging area risk levels
def city_risk_prediction(city_group):
    risk_scores = {"Low": 0, "Medium": 1, "High": 2}
    reverse_risk = {0: "Low", 1: "Medium", 2: "High"}
    avg_risk = city_group['Risk Level'].map(risk_scores).mean()
    return reverse_risk[round(avg_risk)]

city_risk = dangerous_areas.groupby("City").apply(city_risk_prediction).reset_index()
city_risk.columns = ["City", "Predicted Risk Level"]


app = Flask(__name__)


with open("kmeans_model.pkl", "rb") as model_file:
    loaded_kmeans = pickle.load(model_file)

@app.route("/city-risk", methods=["GET"])
def get_city_risk():
    city = request.args.get("city")
    if city:
        risk = city_risk[city_risk["City"].str.lower() == city.lower()]
        if not risk.empty:
            return jsonify(risk.to_dict(orient="records"))
        else:
            return jsonify({"error": "City not found"}), 404
    return jsonify(city_risk.to_dict(orient="records"))

@app.route("/area-risk", methods=["GET"])
def get_area_risk():
    city = request.args.get("city")
    if city:
        areas = dangerous_areas[dangerous_areas["City"].str.lower() == city.lower()][["City", "Area", "Risk Level", "Latitude", "Longitude"]]
        if not areas.empty:
            return jsonify(areas.to_dict(orient="records"))
        else:
            return jsonify({"error": "City not found or no areas listed"}), 404
    return jsonify(dangerous_areas.to_dict(orient="records"))


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True, use_reloader=False)