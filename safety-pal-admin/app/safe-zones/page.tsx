"use client";

import { useEffect, useState } from "react";
import {
  collection,
  addDoc,
  query,
  getDocs,
  deleteDoc,
  doc,
  updateDoc,
} from "firebase/firestore";
import { firestore } from "@/lib/firebaseClient";

interface SafeZone {
  id: string;
  name: string;
  type: string;
  contact: string;
  active: boolean;
  latitude?: number;
  longitude?: number;
  createdAt?: string;
}

export default function SafeZones() {
  const [zones, setZones] = useState<SafeZone[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [formData, setFormData] = useState({
    name: "",
    type: "shelter",
    contact: "",
    latitude: "",
    longitude: "",
  });

  const fetchZones = async () => {
    try {
      const zonesRef = collection(firestore, "safe_zones");
      const snap = await getDocs(query(zonesRef));
      setZones(
        snap.docs.map((doc) => ({
          id: doc.id,
          ...doc.data(),
        })) as SafeZone[],
      );
    } catch (error) {
      console.error("Error fetching zones:", error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchZones();
  }, []);

  const handleAddZone = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      await addDoc(collection(firestore, "safe_zones"), {
        name: formData.name,
        type: formData.type,
        contact: formData.contact,
        location: {
          latitude: parseFloat(formData.latitude),
          longitude: parseFloat(formData.longitude),
        },
        active: true,
        createdAt: new Date().toISOString(),
      });
      setFormData({
        name: "",
        type: "shelter",
        contact: "",
        latitude: "",
        longitude: "",
      });
      setShowForm(false);
      fetchZones();
    } catch (error) {
      console.error("Error adding zone:", error);
    }
  };

  const handleToggle = async (id: string, active: boolean) => {
    try {
      await updateDoc(doc(firestore, "safe_zones", id), { active: !active });
      fetchZones();
    } catch (error) {
      console.error("Error updating zone:", error);
    }
  };

  const handleDelete = async (id: string) => {
    if (confirm("Are you sure you want to delete this safe zone?")) {
      try {
        await deleteDoc(doc(firestore, "safe_zones", id));
        fetchZones();
      } catch (error) {
        console.error("Error deleting zone:", error);
      }
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">Safe Zones</h1>
          <p className="text-gray-600 mt-2">
            Manage shelter and safe locations
          </p>
        </div>
        <button
          onClick={() => setShowForm(!showForm)}
          className="bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700 transition"
        >
          + Add Safe Zone
        </button>
      </div>

      {showForm && (
        <div className="bg-white rounded-lg shadow-lg p-6 border-l-4 border-blue-600">
          <h2 className="text-xl font-bold mb-4">Create New Safe Zone</h2>
          <form onSubmit={handleAddZone} className="space-y-4">
            <input
              type="text"
              placeholder="Zone Name"
              value={formData.name}
              onChange={(e) =>
                setFormData({ ...formData, name: e.target.value })
              }
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-600"
              required
            />
            <select
              value={formData.type}
              onChange={(e) =>
                setFormData({ ...formData, type: e.target.value })
              }
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-600"
            >
              <option value="shelter">Shelter</option>
              <option value="police">Police Station</option>
              <option value="hospital">Hospital</option>
              <option value="community">Community Center</option>
            </select>
            <input
              type="email"
              placeholder="Contact Email"
              value={formData.contact}
              onChange={(e) =>
                setFormData({ ...formData, contact: e.target.value })
              }
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-600"
              required
            />
            <div className="grid grid-cols-2 gap-4">
              <input
                type="number"
                step="0.0001"
                placeholder="Latitude"
                value={formData.latitude}
                onChange={(e) =>
                  setFormData({ ...formData, latitude: e.target.value })
                }
                className="px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-600"
                required
              />
              <input
                type="number"
                step="0.0001"
                placeholder="Longitude"
                value={formData.longitude}
                onChange={(e) =>
                  setFormData({ ...formData, longitude: e.target.value })
                }
                className="px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-600"
                required
              />
            </div>
            <div className="flex gap-2">
              <button
                type="submit"
                className="bg-green-600 text-white px-6 py-2 rounded-lg hover:bg-green-700 transition"
              >
                Create
              </button>
              <button
                type="button"
                onClick={() => setShowForm(false)}
                className="bg-gray-600 text-white px-6 py-2 rounded-lg hover:bg-gray-700 transition"
              >
                Cancel
              </button>
            </div>
          </form>
        </div>
      )}

      {loading ? (
        <div className="text-center py-12">
          <div className="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
          <p className="mt-4 text-gray-600">Loading safe zones...</p>
        </div>
      ) : zones.length === 0 ? (
        <div className="bg-white rounded-lg shadow p-12 text-center">
          <p className="text-gray-600 text-lg">
            No safe zones yet. Create one to get started.
          </p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {zones.map((zone) => (
            <div
              key={zone.id}
              className={`rounded-lg shadow-lg p-6 border-l-4 transition ${
                zone.active
                  ? "border-green-600 bg-white"
                  : "border-gray-300 bg-gray-50"
              }`}
            >
              <div className="flex justify-between items-start mb-4">
                <div>
                  <h3 className="text-xl font-bold text-gray-900">
                    {zone.name}
                  </h3>
                  <p className="text-sm text-gray-600 mt-1 capitalize">
                    {zone.type}
                  </p>
                </div>
                <span
                  className={`px-3 py-1 rounded-full text-xs font-semibold ${
                    zone.active
                      ? "bg-green-100 text-green-800"
                      : "bg-gray-100 text-gray-800"
                  }`}
                >
                  {zone.active ? "Active" : "Inactive"}
                </span>
              </div>
              <p className="text-gray-700 mb-4">📧 {zone.contact}</p>
              {zone.latitude && zone.longitude && (
                <p className="text-sm text-gray-600 mb-4">
                  📍 {zone.latitude}, {zone.longitude}
                </p>
              )}
              <div className="flex gap-2">
                <button
                  onClick={() => handleToggle(zone.id, zone.active)}
                  className={`flex-1 px-3 py-2 rounded text-sm font-semibold transition ${
                    zone.active
                      ? "bg-yellow-600 text-white hover:bg-yellow-700"
                      : "bg-blue-600 text-white hover:bg-blue-700"
                  }`}
                >
                  {zone.active ? "Deactivate" : "Activate"}
                </button>
                <button
                  onClick={() => handleDelete(zone.id)}
                  className="px-3 py-2 bg-red-600 text-white rounded text-sm font-semibold hover:bg-red-700 transition"
                >
                  Delete
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
