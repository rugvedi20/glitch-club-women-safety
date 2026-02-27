"use client";

import { useEffect, useState } from "react";
import { doc, getDoc, setDoc } from "firebase/firestore";
import { firestore } from "@/lib/firebaseClient";

interface SystemSettings {
  community_radius: number;
  risk_decay_days: number;
  min_severity_alert_threshold: number;
}

export default function Settings() {
  const [settings, setSettings] = useState<SystemSettings>({
    community_radius: 5,
    risk_decay_days: 30,
    min_severity_alert_threshold: 3,
  });
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState("");

  useEffect(() => {
    const fetchSettings = async () => {
      try {
        const settingsDoc = await getDoc(
          doc(firestore, "system_settings", "global"),
        );
        if (settingsDoc.exists()) {
          setSettings(settingsDoc.data() as SystemSettings);
        }
      } catch (error) {
        console.error("Error fetching settings:", error);
      } finally {
        setLoading(false);
      }
    };

    fetchSettings();
  }, []);

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    try {
      await setDoc(doc(firestore, "system_settings", "global"), settings);
      setMessage("Settings saved successfully!");
      setTimeout(() => setMessage(""), 3000);
    } catch (error) {
      console.error("Error saving settings:", error);
      setMessage("Error saving settings. Please try again.");
    } finally {
      setSaving(false);
    }
  };

  if (loading) {
    return (
      <div className="text-center py-12">
        <div className="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
        <p className="mt-4 text-gray-600">Loading settings...</p>
      </div>
    );
  }

  return (
    <div className="max-w-2xl space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-gray-900">System Settings</h1>
        <p className="text-gray-600 mt-2">Configure global system parameters</p>
      </div>

      {message && (
        <div
          className={`p-4 rounded-lg ${
            message.includes("successfully")
              ? "bg-green-100 text-green-800"
              : "bg-red-100 text-red-800"
          }`}
        >
          {message}
        </div>
      )}

      <form
        onSubmit={handleSave}
        className="bg-white rounded-lg shadow-lg p-8 space-y-6"
      >
        <div>
          <label className="block text-sm font-semibold text-gray-900 mb-2">
            Community Radius (km)
          </label>
          <input
            type="number"
            min="1"
            value={settings.community_radius}
            onChange={(e) =>
              setSettings({
                ...settings,
                community_radius: parseFloat(e.target.value),
              })
            }
            className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-600"
          />
          <p className="text-sm text-gray-600 mt-2">
            Radius within which incidents are considered part of the same
            community
          </p>
        </div>

        <div>
          <label className="block text-sm font-semibold text-gray-900 mb-2">
            Risk Decay Days
          </label>
          <input
            type="number"
            min="1"
            value={settings.risk_decay_days}
            onChange={(e) =>
              setSettings({
                ...settings,
                risk_decay_days: parseFloat(e.target.value),
              })
            }
            className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-600"
          />
          <p className="text-sm text-gray-600 mt-2">
            Number of days after which incident severity decreases
          </p>
        </div>

        <div>
          <label className="block text-sm font-semibold text-gray-900 mb-2">
            Min Severity Alert Threshold (1-5)
          </label>
          <input
            type="number"
            min="1"
            max="5"
            value={settings.min_severity_alert_threshold}
            onChange={(e) =>
              setSettings({
                ...settings,
                min_severity_alert_threshold: parseFloat(e.target.value),
              })
            }
            className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-600"
          />
          <p className="text-sm text-gray-600 mt-2">
            Minimum severity level that triggers system alerts
          </p>
        </div>

        <button
          type="submit"
          disabled={saving}
          className="w-full bg-blue-600 text-white py-3 rounded-lg font-semibold hover:bg-blue-700 transition disabled:bg-gray-400"
        >
          {saving ? "Saving..." : "Save Settings"}
        </button>
      </form>
    </div>
  );
}
