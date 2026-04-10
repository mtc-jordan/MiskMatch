"use client";

import { useEffect, useState, useCallback } from "react";
import { BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer } from "recharts";
import Sidebar from "@/components/Sidebar";
import Badge from "@/components/Badge";
import Pagination from "@/components/Pagination";
import { getMatches, getMatchStats, MatchListResponse, MatchFunnelStats } from "@/lib/api";

export default function MatchesPage() {
  const [data, setData] = useState<MatchListResponse | null>(null);
  const [funnel, setFunnel] = useState<MatchFunnelStats | null>(null);
  const [page, setPage] = useState(1);
  const [statusFilter, setStatusFilter] = useState("");
  const [error, setError] = useState("");

  const load = useCallback(() => {
    setError("");
    getMatches({ page, status: statusFilter || undefined }).then(setData).catch((e) => setError(e.message));
  }, [page, statusFilter]);

  useEffect(() => { load(); }, [load]);
  useEffect(() => { getMatchStats().then(setFunnel).catch(() => {}); }, []);

  const funnelData = funnel
    ? [
        { stage: "Pending", count: funnel.total_pending },
        { stage: "Mutual", count: funnel.total_mutual },
        { stage: "Approved", count: funnel.total_approved },
        { stage: "Active", count: funnel.total_active },
        { stage: "Nikah", count: funnel.total_nikah },
        { stage: "Closed", count: funnel.total_closed },
      ]
    : [];

  return (
    <div className="ml-64 min-h-screen">
      <Sidebar />
      <div className="p-8">
        <h2 className="text-2xl font-bold text-misk-900 mb-6">Matches</h2>

        {/* Funnel chart */}
        {funnel && (
          <div className="bg-white rounded-xl shadow-sm p-6 mb-6">
            <h3 className="text-sm font-semibold text-gray-700 mb-4">Match Funnel</h3>
            <div className="grid grid-cols-3 gap-4 mb-4 text-sm">
              <div className="text-center">
                <p className="text-gray-500">Pending &rarr; Mutual</p>
                <p className="text-xl font-bold text-misk-800">{(funnel.pending_to_mutual_rate * 100).toFixed(1)}%</p>
              </div>
              <div className="text-center">
                <p className="text-gray-500">Mutual &rarr; Active</p>
                <p className="text-xl font-bold text-misk-800">{(funnel.mutual_to_active_rate * 100).toFixed(1)}%</p>
              </div>
              <div className="text-center">
                <p className="text-gray-500">Active &rarr; Nikah</p>
                <p className="text-xl font-bold text-gold-600">{(funnel.active_to_nikah_rate * 100).toFixed(1)}%</p>
              </div>
            </div>
            <div className="h-48">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={funnelData}>
                  <XAxis dataKey="stage" tick={{ fontSize: 12 }} />
                  <YAxis allowDecimals={false} tick={{ fontSize: 11 }} />
                  <Tooltip />
                  <Bar dataKey="count" fill="#8B7355" radius={[4, 4, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            </div>
          </div>
        )}

        {/* Filter */}
        <div className="flex gap-3 mb-6">
          <select value={statusFilter} onChange={(e) => { setStatusFilter(e.target.value); setPage(1); }} className="px-3 py-2 border rounded-lg text-sm">
            <option value="">All Statuses</option>
            <option value="pending">Pending</option>
            <option value="mutual">Mutual</option>
            <option value="approved">Approved</option>
            <option value="active">Active</option>
            <option value="nikah">Nikah</option>
            <option value="closed">Closed</option>
            <option value="blocked">Blocked</option>
          </select>
        </div>

        {error && <div className="bg-red-50 text-red-700 rounded-lg p-4 mb-4">{error}</div>}

        <div className="bg-white rounded-xl shadow-sm overflow-hidden">
          <table className="w-full text-sm">
            <thead>
              <tr className="bg-gray-50 text-left text-gray-600 font-medium">
                <th className="px-4 py-3">Sender</th>
                <th className="px-4 py-3">Receiver</th>
                <th className="px-4 py-3">Status</th>
                <th className="px-4 py-3">Score</th>
                <th className="px-4 py-3">Created</th>
                <th className="px-4 py-3">Mutual At</th>
              </tr>
            </thead>
            <tbody className="divide-y">
              {data?.matches.map((m) => (
                <tr key={m.id} className="hover:bg-gray-50 transition-colors">
                  <td className="px-4 py-3">{m.sender_phone}</td>
                  <td className="px-4 py-3">{m.receiver_phone}</td>
                  <td className="px-4 py-3"><Badge value={m.status} /></td>
                  <td className="px-4 py-3">{m.compatibility_score ? `${(m.compatibility_score * 100).toFixed(0)}%` : "—"}</td>
                  <td className="px-4 py-3 text-gray-500">{new Date(m.created_at).toLocaleDateString()}</td>
                  <td className="px-4 py-3 text-gray-500">{m.became_mutual_at ? new Date(m.became_mutual_at).toLocaleDateString() : "—"}</td>
                </tr>
              ))}
              {data?.matches.length === 0 && (
                <tr><td colSpan={6} className="px-4 py-8 text-center text-gray-400">No matches found</td></tr>
              )}
            </tbody>
          </table>
        </div>

        {data && <Pagination page={data.page} total={data.total} pageSize={data.page_size} onChange={setPage} />}
      </div>
    </div>
  );
}
