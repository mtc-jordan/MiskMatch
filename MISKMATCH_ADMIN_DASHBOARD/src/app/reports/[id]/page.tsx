"use client";

import { useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import Sidebar from "@/components/Sidebar";
import Badge from "@/components/Badge";
import { getReportDetail, resolveReport, ReportDetail } from "@/lib/api";

export default function ReportDetailPage() {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();
  const [data, setData] = useState<ReportDetail | null>(null);
  const [error, setError] = useState("");
  const [resolving, setResolving] = useState(false);
  const [actionMsg, setActionMsg] = useState("");

  useEffect(() => {
    getReportDetail(id).then(setData).catch((e) => setError(e.message));
  }, [id]);

  async function handleResolve(action: string) {
    const note = prompt(`Resolution note for "${action}":`);
    setResolving(true);
    try {
      const res = await resolveReport(id, action, note || undefined);
      setActionMsg(res.message);
      if (data) {
        setData({ ...data, report: { ...data.report, status: action === "dismiss" ? "dismissed" : "resolved" } });
      }
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Failed");
    } finally {
      setResolving(false);
    }
  }

  if (error) {
    return (
      <div className="ml-64 p-8">
        <Sidebar />
        <div className="bg-red-50 text-red-700 rounded-lg p-4">{error}</div>
      </div>
    );
  }

  if (!data) {
    return (
      <div className="ml-64 p-8">
        <Sidebar />
        <div className="animate-pulse space-y-4">
          <div className="h-8 bg-gray-200 rounded w-64" />
          <div className="h-48 bg-gray-200 rounded-xl" />
        </div>
      </div>
    );
  }

  const { report, reporter, reported } = data;

  return (
    <div className="ml-64 min-h-screen">
      <Sidebar />
      <div className="p-8">
        <button onClick={() => router.back()} className="text-sm text-misk-600 hover:text-misk-800 mb-4 inline-block">&larr; Back to Reports</button>
        <h2 className="text-2xl font-bold text-misk-900 mb-1">Report: {report.reason}</h2>
        <p className="text-sm text-gray-500 mb-6">ID: {report.id}</p>

        {actionMsg && <div className="bg-emerald-50 text-emerald-700 rounded-lg p-3 mb-4 text-sm">{actionMsg}</div>}

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Report details */}
          <div className="bg-white rounded-xl shadow-sm p-6 lg:col-span-2">
            <h3 className="text-sm font-semibold text-gray-700 mb-4">Details</h3>
            <div className="space-y-3 text-sm">
              <div><span className="text-gray-500">Status:</span> <Badge value={report.status} /></div>
              <div><span className="text-gray-500">Reason:</span> <span className="font-medium">{report.reason}</span></div>
              {report.description && <div><span className="text-gray-500">Description:</span> <p className="mt-1 text-gray-700">{report.description}</p></div>}
              <div><span className="text-gray-500">Block requested:</span> {report.is_block ? "Yes" : "No"}</div>
              <div><span className="text-gray-500">Filed:</span> {new Date(report.created_at).toLocaleString()}</div>
              {report.resolution && <div><span className="text-gray-500">Resolution:</span> {report.resolution}</div>}
            </div>

            {report.evidence_urls && report.evidence_urls.length > 0 && (
              <div className="mt-4">
                <span className="text-sm text-gray-500">Evidence:</span>
                <div className="flex gap-2 mt-2">
                  {report.evidence_urls.map((url, i) => (
                    <a key={i} href={url} target="_blank" rel="noopener noreferrer" className="text-misk-600 hover:text-misk-800 text-xs underline">
                      File {i + 1}
                    </a>
                  ))}
                </div>
              </div>
            )}
          </div>

          {/* People + Actions */}
          <div className="space-y-4">
            <PersonCard label="Reporter" person={reporter} />
            <PersonCard label="Reported" person={reported} />

            {report.status === "pending" && (
              <div className="bg-white rounded-xl shadow-sm p-6">
                <h3 className="text-sm font-semibold text-gray-700 mb-3">Take Action</h3>
                <div className="space-y-2">
                  <button disabled={resolving} onClick={() => handleResolve("warn")} className="w-full px-4 py-2 bg-amber-500 text-white rounded-lg text-sm font-medium hover:bg-amber-600 disabled:opacity-50">
                    Warn User
                  </button>
                  <button disabled={resolving} onClick={() => handleResolve("ban")} className="w-full px-4 py-2 bg-red-600 text-white rounded-lg text-sm font-medium hover:bg-red-700 disabled:opacity-50">
                    Ban User
                  </button>
                  <button disabled={resolving} onClick={() => handleResolve("dismiss")} className="w-full px-4 py-2 bg-gray-200 text-gray-700 rounded-lg text-sm font-medium hover:bg-gray-300 disabled:opacity-50">
                    Dismiss Report
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

function PersonCard({ label, person }: { label: string; person: { id: string; phone: string; email: string | null; status: string; first_name: string | null; last_name: string | null } }) {
  return (
    <div className="bg-white rounded-xl shadow-sm p-6">
      <h3 className="text-sm font-semibold text-gray-700 mb-3">{label}</h3>
      <div className="space-y-2 text-sm">
        <div className="flex justify-between"><span className="text-gray-500">Phone</span><span>{person.phone}</span></div>
        {person.first_name && <div className="flex justify-between"><span className="text-gray-500">Name</span><span>{person.first_name} {person.last_name}</span></div>}
        <div className="flex justify-between"><span className="text-gray-500">Status</span><Badge value={person.status} /></div>
      </div>
    </div>
  );
}
