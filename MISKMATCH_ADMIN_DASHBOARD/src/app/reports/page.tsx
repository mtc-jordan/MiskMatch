"use client";

import { useEffect, useState, useCallback } from "react";
import Link from "next/link";
import Sidebar from "@/components/Sidebar";
import Badge from "@/components/Badge";
import Pagination from "@/components/Pagination";
import { getReports, ReportListResponse } from "@/lib/api";

export default function ReportsPage() {
  const [data, setData] = useState<ReportListResponse | null>(null);
  const [page, setPage] = useState(1);
  const [statusFilter, setStatusFilter] = useState("pending");
  const [error, setError] = useState("");

  const load = useCallback(() => {
    setError("");
    getReports({ page, status: statusFilter || undefined })
      .then(setData)
      .catch((e) => setError(e.message));
  }, [page, statusFilter]);

  useEffect(() => { load(); }, [load]);

  return (
    <div className="ml-64 min-h-screen">
      <Sidebar />
      <div className="p-8">
        <h2 className="text-2xl font-bold text-misk-900 mb-6">Reports</h2>

        <div className="flex gap-3 mb-6">
          <select value={statusFilter} onChange={(e) => { setStatusFilter(e.target.value); setPage(1); }} className="px-3 py-2 border rounded-lg text-sm">
            <option value="">All</option>
            <option value="pending">Pending</option>
            <option value="resolved">Resolved</option>
            <option value="dismissed">Dismissed</option>
          </select>
        </div>

        {error && <div className="bg-red-50 text-red-700 rounded-lg p-4 mb-4">{error}</div>}

        <div className="bg-white rounded-xl shadow-sm overflow-hidden">
          <table className="w-full text-sm">
            <thead>
              <tr className="bg-gray-50 text-left text-gray-600 font-medium">
                <th className="px-4 py-3">Reason</th>
                <th className="px-4 py-3">Reporter</th>
                <th className="px-4 py-3">Reported</th>
                <th className="px-4 py-3">Status</th>
                <th className="px-4 py-3">Block?</th>
                <th className="px-4 py-3">Date</th>
                <th className="px-4 py-3"></th>
              </tr>
            </thead>
            <tbody className="divide-y">
              {data?.reports.map((r) => (
                <tr key={r.id} className="hover:bg-gray-50 transition-colors">
                  <td className="px-4 py-3 font-medium">{r.reason}</td>
                  <td className="px-4 py-3 text-gray-500 font-mono text-xs">{r.reporter_id.slice(0, 8)}...</td>
                  <td className="px-4 py-3 text-gray-500 font-mono text-xs">{r.reported_id.slice(0, 8)}...</td>
                  <td className="px-4 py-3"><Badge value={r.status} /></td>
                  <td className="px-4 py-3">{r.is_block ? "Yes" : "—"}</td>
                  <td className="px-4 py-3 text-gray-500">{new Date(r.created_at).toLocaleDateString()}</td>
                  <td className="px-4 py-3">
                    <Link href={`/reports/${r.id}`} className="text-misk-600 hover:text-misk-800 text-sm font-medium">
                      Review
                    </Link>
                  </td>
                </tr>
              ))}
              {data?.reports.length === 0 && (
                <tr><td colSpan={7} className="px-4 py-8 text-center text-gray-400">No reports found</td></tr>
              )}
            </tbody>
          </table>
        </div>

        {data && <Pagination page={data.page} total={data.total} pageSize={data.page_size} onChange={setPage} />}
      </div>
    </div>
  );
}
