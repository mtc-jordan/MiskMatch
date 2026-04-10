"use client";

import { useEffect, useState, useCallback } from "react";
import Sidebar from "@/components/Sidebar";
import Pagination from "@/components/Pagination";
import { getFlaggedMessages, FlaggedMessageListResponse } from "@/lib/api";

export default function FlaggedMessagesPage() {
  const [data, setData] = useState<FlaggedMessageListResponse | null>(null);
  const [page, setPage] = useState(1);
  const [error, setError] = useState("");

  const load = useCallback(() => {
    setError("");
    getFlaggedMessages(page).then(setData).catch((e) => setError(e.message));
  }, [page]);

  useEffect(() => { load(); }, [load]);

  return (
    <div className="ml-64 min-h-screen">
      <Sidebar />
      <div className="p-8">
        <h2 className="text-2xl font-bold text-misk-900 mb-6">Flagged Messages</h2>

        {error && <div className="bg-red-50 text-red-700 rounded-lg p-4 mb-4">{error}</div>}

        <div className="space-y-3">
          {data?.messages.map((m) => (
            <div key={m.id} className="bg-white rounded-xl shadow-sm p-5">
              <div className="flex justify-between items-start mb-2">
                <div>
                  <span className="text-sm font-medium text-gray-800">{m.sender_phone}</span>
                  <span className="text-xs text-gray-400 ml-2">{m.content_type}</span>
                </div>
                <span className="text-xs text-gray-400">{new Date(m.created_at).toLocaleString()}</span>
              </div>
              <p className="text-sm text-gray-700 bg-gray-50 rounded-lg p-3 border">{m.content}</p>
              {m.moderation_reason && (
                <div className="mt-2 flex items-center gap-2">
                  <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-700">
                    Flagged
                  </span>
                  <span className="text-xs text-gray-500">{m.moderation_reason}</span>
                </div>
              )}
              <div className="mt-2 text-xs text-gray-400">
                Match: {m.match_id.slice(0, 8)}... | Sender: {m.sender_id.slice(0, 8)}...
              </div>
            </div>
          ))}
          {data?.messages.length === 0 && (
            <div className="bg-white rounded-xl shadow-sm p-8 text-center text-gray-400">No flagged messages</div>
          )}
        </div>

        {data && <Pagination page={data.page} total={data.total} pageSize={data.page_size} onChange={setPage} />}
      </div>
    </div>
  );
}
