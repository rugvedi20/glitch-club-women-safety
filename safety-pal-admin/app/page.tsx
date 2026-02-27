"use client";

import { useEffect, useState } from "react";
import {
  collection,
  query,
  where,
  getDocs,
  Timestamp,
} from "firebase/firestore";
import { firestore } from "@/lib/firebaseClient";

interface DashboardStats {
  pending: number;
  validated: number;
  rejected: number;
  todayReports: number;
  weekReports: number;
  topIncidentType: string;
}

export default function Dashboard() {
  const [stats, setStats] = useState<DashboardStats>({
    pending: 0,
    validated: 0,
    rejected: 0,
    todayReports: 0,
    weekReports: 0,
    topIncidentType: "—",
  });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchStats = async () => {
      try {
        const reportsRef = collection(firestore, "incident_reports");

        // Pending count
        const pendingSnap = await getDocs(
          query(reportsRef, where("status", "==", "pending")),
        );
        const pending = pendingSnap.size;

        // Validated count
        const validatedSnap = await getDocs(
          query(reportsRef, where("status", "==", "validated")),
        );
        const validated = validatedSnap.size;

        // Rejected count
        const rejectedSnap = await getDocs(
          query(reportsRef, where("status", "==", "rejected")),
        );
        const rejected = rejectedSnap.size;

        // Today's reports
        const now = new Date();
        const startOfToday = new Date(
          now.getFullYear(),
          now.getMonth(),
          now.getDate(),
        );
        const todaySnap = await getDocs(
          query(
            reportsRef,
            where("submittedAt", ">=", Timestamp.fromDate(startOfToday)),
          ),
        );
        const todayReports = todaySnap.size;

        // This week's reports
        const startOfWeek = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
        const weekSnap = await getDocs(
          query(
            reportsRef,
            where("submittedAt", ">=", Timestamp.fromDate(startOfWeek)),
          ),
        );
        const weekReports = weekSnap.size;

        // Top incident type
        const allSnap = await getDocs(reportsRef);
        const typeCounts: { [key: string]: number } = {};
        allSnap.docs.forEach((doc) => {
          const type = doc.data().incidentType || "Unknown";
          typeCounts[type] = (typeCounts[type] || 0) + 1;
        });
        const topType =
          Object.entries(typeCounts).sort(([, a], [, b]) => b - a)[0]?.[0] ||
          "—";

        setStats({
          pending,
          validated,
          rejected,
          todayReports,
          weekReports,
          topIncidentType: topType,
        });
      } catch (error) {
        console.error("Error fetching stats:", error);
      } finally {
        setLoading(false);
      }
    };

    fetchStats();
  }, []);

  const StatCard = ({
    label,
    value,
    color,
  }: {
    label: string;
    value: number | string;
    color: string;
  }) => (
    <div
      className={`${color} rounded-lg p-6 text-white shadow-lg hover:shadow-xl transition-shadow`}
    >
      <p className="text-sm font-medium opacity-90">{label}</p>
      <p className="text-4xl font-bold mt-2">{value}</p>
    </div>
  );

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-3xl font-bold text-gray-900">Dashboard</h1>
        <p className="text-gray-600 mt-2">Overview of all incident reports</p>
      </div>

      {loading ? (
        <div className="text-center py-12">
          <div className="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
          <p className="mt-4 text-gray-600">Loading stats...</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          <StatCard
            label="Pending Review"
            value={stats.pending}
            color="bg-yellow-500"
          />
          <StatCard
            label="Validated"
            value={stats.validated}
            color="bg-green-500"
          />
          <StatCard
            label="Rejected"
            value={stats.rejected}
            color="bg-red-500"
          />
          <StatCard
            label="Reports Today"
            value={stats.todayReports}
            color="bg-blue-500"
          />
          <StatCard
            label="Reports This Week"
            value={stats.weekReports}
            color="bg-purple-500"
          />
          <StatCard
            label="Top Incident Type"
            value={stats.topIncidentType}
            color="bg-indigo-500"
          />
        </div>
      )}
    </div>
  );
}
