"use client";

import { useEffect, useState } from "react";
import { firestore } from "@/lib/firebaseClient";
import {
  collection,
  query,
  where,
  getDocs,
  updateDoc,
  doc,
  addDoc,
  Timestamp,
} from "firebase/firestore";

type Incident = {
  id: string;
  incidentType?: string;
  description?: string;
  severityReported?: number;
  images?: string[];
  locationName?: string;
  submittedAt?: { seconds: number } | string | null;
};

export default function IncidentsPage() {
  const [incidents, setIncidents] = useState<Incident[]>([]);
  const [status, setStatus] = useState<"pending" | "validated" | "rejected">(
    "pending",
  );
  const [page, setPage] = useState(1);
  const [pageSize] = useState(10);
  const [filterType, setFilterType] = useState<string | "">("");
  const [dateFrom, setDateFrom] = useState<string | "">("");
  const [dateTo, setDateTo] = useState<string | "">("");
  const [selectedSeverity, setSelectedSeverity] = useState<
    Record<string, number>
  >({});
  const [viewingImage, setViewingImage] = useState<string | null>(null);
  const [viewingMap, setViewingMap] = useState<{
    lat?: number;
    lng?: number;
    q?: string;
  } | null>(null);
  const [loading, setLoading] = useState(false);
  const [processingId, setProcessingId] = useState<string | null>(null);
  const [toast, setToast] = useState<string | null>(null);
  const [rejecting, setRejecting] = useState<{ id: string; open: boolean }>({
    id: "",
    open: false,
  });
  const [rejectReason, setRejectReason] = useState("");

  useEffect(() => {
    fetchIncidents();
  }, [status]);

  async function fetchIncidents() {
    setLoading(true);
    setPage(1);
    try {
      const q = query(
        collection(firestore, "incident_reports"),
        where("status", "==", status),
      );
      const snapshot = await getDocs(q);
      const data = snapshot.docs.map((doc) => ({
        id: doc.id,
        ...doc.data(),
      })) as Incident[];
      setIncidents(data);
    } catch (err: any) {
      setToast(err?.message || "Failed to load incidents");
    } finally {
      setLoading(false);
    }
  }

  function toDate(submittedAt: any) {
    if (!submittedAt) return null;
    // Check for Firestore Timestamp with toDate method first
    if (typeof submittedAt.toDate === "function") return submittedAt.toDate();
    // Then check for object with seconds (fallback for serialized timestamps)
    if (typeof submittedAt.seconds === "number")
      return new Date(submittedAt.seconds * 1000);
    // Check for string
    if (typeof submittedAt === "string") return new Date(submittedAt);
    return null;
  }

  async function approve(incidentId: string, severity = 3) {
    if (processingId) return;
    setProcessingId(incidentId);
    try {
      const docRef = doc(firestore, "incident_reports", incidentId);
      await updateDoc(docRef, {
        status: "validated",
        validatedBy: "admin-system",
        validatedAt: Timestamp.now(),
        adminSeverity: severity,
      });
      // Log activity
      await addDoc(collection(firestore, "admin_activity_logs"), {
        adminUid: "admin-system",
        actionType: "approve_incident",
        targetId: incidentId,
        timestamp: Timestamp.now(),
        details: { adminSeverity: severity },
      });
      setToast("Approved");
      fetchIncidents();
    } catch (err: any) {
      setToast(err?.message || "Approve failed");
    } finally {
      setProcessingId(null);
    }
  }

  function openReject(id: string) {
    setRejecting({ id, open: true });
  }

  async function submitReject() {
    if (!rejecting.id) return;
    setProcessingId(rejecting.id);
    try {
      const docRef = doc(firestore, "incident_reports", rejecting.id);
      await updateDoc(docRef, {
        status: "rejected",
        validatedBy: "admin-system",
        validatedAt: Timestamp.now(),
        rejectionReason: rejectReason,
      });
      // Log activity
      await addDoc(collection(firestore, "admin_activity_logs"), {
        adminUid: "admin-system",
        actionType: "reject_incident",
        targetId: rejecting.id,
        timestamp: Timestamp.now(),
        details: { reason: rejectReason },
      });
      setToast("Rejected");
      fetchIncidents();
      setRejectReason("");
      setRejecting({ id: "", open: false });
    } catch (err: any) {
      setToast(err?.message || "Reject failed");
    } finally {
      setProcessingId(null);
    }
  }

  return (
    <div className="p-6">
      <div className="mb-6">
        <h1 className="text-2xl font-bold mb-6">Incidents Management</h1>

        {/* Status Tabs */}
        <div className="flex gap-2 border-b border-gray-200">
          <button
            onClick={() => setStatus("pending")}
            className={`px-6 py-3 font-semibold border-b-2 transition ${
              status === "pending"
                ? "border-yellow-500 text-yellow-600"
                : "border-transparent text-gray-600 hover:text-gray-900"
            }`}
          >
            🔴 Pending ({incidents.length})
          </button>
          <button
            onClick={() => setStatus("validated")}
            className={`px-6 py-3 font-semibold border-b-2 transition ${
              status === "validated"
                ? "border-green-500 text-green-600"
                : "border-transparent text-gray-600 hover:text-gray-900"
            }`}
          >
            ✅ Validated
          </button>
          <button
            onClick={() => setStatus("rejected")}
            className={`px-6 py-3 font-semibold border-b-2 transition ${
              status === "rejected"
                ? "border-red-500 text-red-600"
                : "border-transparent text-gray-600 hover:text-gray-900"
            }`}
          >
            ❌ Rejected
          </button>
        </div>
      </div>

      {/* Filters */}
      <div className="flex gap-2 mb-4 items-end">
        <div>
          <label className="block text-sm">Type</label>
          <input
            className="border p-1"
            value={filterType}
            onChange={(e) => setFilterType(e.target.value)}
            placeholder="e.g. harassment"
          />
        </div>
        <div>
          <label className="block text-sm">From</label>
          <input
            type="date"
            className="border p-1"
            value={dateFrom}
            onChange={(e) => setDateFrom(e.target.value)}
          />
        </div>
        <div>
          <label className="block text-sm">To</label>
          <input
            type="date"
            className="border p-1"
            value={dateTo}
            onChange={(e) => setDateTo(e.target.value)}
          />
        </div>
        <div>
          <button
            className="bg-gray-200 px-3 py-1 rounded"
            onClick={() => {
              setFilterType("");
              setDateFrom("");
              setDateTo("");
            }}
          >
            Clear
          </button>
        </div>
      </div>

      {/* pagination + list processing */}
      {/** compute filtered and paged list */}
      {(() => {
        const filtered = incidents.filter((i) => {
          if (
            filterType &&
            i.incidentType &&
            !i.incidentType.toLowerCase().includes(filterType.toLowerCase())
          )
            return false;
          const d = toDate(i.submittedAt);
          if (dateFrom) {
            const from = new Date(dateFrom);
            if (!d || d < from) return false;
          }
          if (dateTo) {
            const to = new Date(dateTo);
            to.setHours(23, 59, 59, 999);
            if (!d || d > to) return false;
          }
          return true;
        });

        const total = filtered.length;
        const pages = Math.max(1, Math.ceil(total / pageSize));
        const currentPage = Math.min(page, pages);
        const start = (currentPage - 1) * pageSize;
        const pageItems = filtered.slice(start, start + pageSize);

        return (
          <div>
            <div className="mb-2 text-sm text-gray-600">
              Showing {start + 1} - {Math.min(start + pageSize, total)} of{" "}
              {total}
            </div>
            <ul className="space-y-4">
              {pageItems.map((inc) => (
                <li
                  key={inc.id}
                  className="border border-gray-300 bg-white p-5 rounded-lg shadow-sm hover:shadow-md transition"
                >
                  <div className="flex justify-between gap-4">
                    <div className="flex-1">
                      <div className="font-bold text-lg text-gray-800">
                        {inc.incidentType || "Unknown Type"}
                      </div>
                      <div className="text-sm text-gray-600">
                        {inc.locationName || ""}
                      </div>
                      <div className="mt-2">
                        {inc.description ? (
                          <p>{inc.description}</p>
                        ) : (
                          <p className="italic text-gray-400">
                            No description provided
                          </p>
                        )}
                      </div>

                      {/* images section */}
                      {inc.images && inc.images.length > 0 ? (
                        <div className="flex gap-2 mt-3">
                          {inc.images.slice(0, 4).map((src, idx) => (
                            <img
                              key={idx}
                              src={src}
                              alt={`img-${idx}`}
                              className="w-20 h-20 object-cover rounded cursor-pointer border"
                              onClick={() => setViewingImage(src)}
                            />
                          ))}
                        </div>
                      ) : (
                        <div className="mt-3 text-sm text-gray-400 italic">
                          No images attached
                        </div>
                      )}
                    </div>

                    <div className="flex flex-col items-end gap-3 min-w-fit">
                      <div className="text-xs text-gray-500 bg-gray-100 px-2 py-1 rounded">
                        {toDate(inc.submittedAt)?.toLocaleString() ??
                          "Unknown date"}
                      </div>
                      <div className="flex gap-2 items-center">
                        <label className="text-sm font-medium text-gray-700">
                          Severity
                        </label>
                        <select
                          value={selectedSeverity[inc.id] ?? 3}
                          onChange={(e) =>
                            setSelectedSeverity((prev) => ({
                              ...prev,
                              [inc.id]: Number(e.target.value),
                            }))
                          }
                          className="border border-gray-300 p-1 rounded text-sm"
                        >
                          {[1, 2, 3, 4, 5].map((n) => (
                            <option key={n} value={n}>
                              {n}
                            </option>
                          ))}
                        </select>
                      </div>

                      {/* Show different actions based on status */}
                      {status === "pending" && (
                        <div className="flex gap-2">
                          <button
                            className="bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded text-sm font-medium disabled:opacity-50 transition"
                            onClick={() =>
                              approve(inc.id, selectedSeverity[inc.id] ?? 3)
                            }
                            disabled={!!processingId}
                          >
                            ✓ Approve
                          </button>
                          <button
                            className="bg-red-600 hover:bg-red-700 text-white px-4 py-2 rounded text-sm font-medium disabled:opacity-50 transition"
                            onClick={() => openReject(inc.id)}
                            disabled={!!processingId}
                          >
                            ✕ Reject
                          </button>
                        </div>
                      )}

                      {status === "validated" && (inc as any).validatedAt && (
                        <div className="text-xs bg-green-100 text-green-800 px-3 py-2 rounded">
                          ✓ Validated at{" "}
                          {toDate((inc as any).validatedAt)?.toLocaleString()}
                        </div>
                      )}

                      {status === "rejected" &&
                        (inc as any).rejectionReason && (
                          <div className="text-xs bg-red-100 text-red-800 px-3 py-2 rounded">
                            <strong>Reason:</strong>{" "}
                            {(inc as any).rejectionReason}
                          </div>
                        )}

                      {/* map button */}
                      <div>
                        <button
                          className="text-sm text-blue-600 underline"
                          onClick={() => {
                            // try to parse coordinates from any stored location shape
                            const locAny: any = (inc as any).location || null;
                            if (locAny) {
                              const lat =
                                locAny.latitude ??
                                locAny._latitude ??
                                locAny.lat;
                              const lng =
                                locAny.longitude ??
                                locAny._longitude ??
                                locAny.lng;
                              if (lat && lng) {
                                setViewingMap({
                                  lat: Number(lat),
                                  lng: Number(lng),
                                });
                                return;
                              }
                            }
                            if (inc.locationName)
                              setViewingMap({ q: inc.locationName });
                          }}
                        >
                          View Map
                        </button>
                      </div>
                    </div>
                  </div>
                </li>
              ))}
            </ul>

            {/* pagination controls */}
            <div className="flex justify-between items-center mt-4">
              <div>
                <button
                  className="px-3 py-1 mr-2 bg-gray-200 rounded"
                  onClick={() => setPage((p) => Math.max(1, p - 1))}
                >
                  Previous
                </button>
                <button
                  className="px-3 py-1 bg-gray-200 rounded"
                  onClick={() => setPage((p) => p + 1)}
                >
                  Next
                </button>
              </div>
              <div className="text-sm text-gray-500">
                Page {currentPage} / {pages}
              </div>
            </div>
          </div>
        );
      })()}

      {toast && (
        <div className="mb-4 p-2 bg-green-100 text-green-800 rounded">
          {toast}
        </div>
      )}

      {loading ? (
        <div>Loading...</div>
      ) : incidents.length === 0 ? (
        <div>No pending incidents</div>
      ) : (
        <ul className="space-y-4">
          {incidents.map((inc) => (
            <li key={inc.id} className="border p-4 rounded">
              <div className="flex justify-between">
                <div>
                  <div className="font-semibold">
                    {inc.incidentType || "Unknown"}
                  </div>
                  <div className="text-sm text-gray-600">
                    {inc.locationName || ""}
                  </div>
                  <div className="mt-2">{inc.description}</div>
                </div>
                <div className="flex flex-col items-end gap-2">
                  <div className="text-sm text-gray-500">
                    Reported: {inc.submittedAt ? String(inc.submittedAt) : "-"}
                  </div>
                  <div className="flex gap-2">
                    <button
                      className="bg-green-600 text-white px-3 py-1 rounded disabled:opacity-50"
                      onClick={() => approve(inc.id, 3)}
                      disabled={!!processingId}
                    >
                      Approve
                    </button>
                    <button
                      className="bg-red-600 text-white px-3 py-1 rounded disabled:opacity-50"
                      onClick={() => openReject(inc.id)}
                      disabled={!!processingId}
                    >
                      Reject
                    </button>
                  </div>
                </div>
              </div>
            </li>
          ))}
        </ul>
      )}

      {/* Reject modal */}
      {rejecting.open && (
        <div className="fixed inset-0 bg-black/40 flex items-center justify-center">
          <div className="bg-white p-6 rounded w-96">
            <h2 className="text-lg font-semibold mb-2">Reject Incident</h2>
            <textarea
              className="border p-2 w-full mb-4"
              rows={4}
              value={rejectReason}
              onChange={(e) => setRejectReason(e.target.value)}
            />
            <div className="flex justify-end gap-2">
              <button
                className="px-3 py-1"
                onClick={() => setRejecting({ id: "", open: false })}
              >
                Cancel
              </button>
              <button
                className="bg-red-600 text-white px-3 py-1 rounded"
                onClick={submitReject}
                disabled={!rejectReason || !!processingId}
              >
                Confirm Reject
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Image modal */}
      {viewingImage && (
        <div
          className="fixed inset-0 bg-black/60 flex items-center justify-center"
          onClick={() => setViewingImage(null)}
        >
          <img
            src={viewingImage}
            alt="preview"
            className="max-h-[80vh] max-w-[90vw] shadow-lg"
          />
        </div>
      )}

      {/* Map modal */}
      {viewingMap && (
        <div className="fixed inset-0 bg-black/60 flex items-center justify-center">
          <div className="bg-white rounded overflow-hidden w-[90vw] h-[80vh]">
            <div className="flex justify-end p-2">
              <button className="px-2" onClick={() => setViewingMap(null)}>
                Close
              </button>
            </div>
            <div className="h-[calc(100%-48px)]">
              {viewingMap.lat && viewingMap.lng ? (
                <iframe
                  className="w-full h-full"
                  src={`https://maps.google.com/maps?q=${viewingMap.lat},${viewingMap.lng}&z=15&output=embed`}
                />
              ) : viewingMap.q ? (
                <iframe
                  className="w-full h-full"
                  src={`https://maps.google.com/maps?q=${encodeURIComponent(viewingMap.q)}&z=13&output=embed`}
                />
              ) : (
                <div className="p-4">No location available</div>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
