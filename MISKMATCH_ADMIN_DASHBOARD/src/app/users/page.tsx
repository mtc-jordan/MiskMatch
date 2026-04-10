"use client";

import { useEffect, useState, useCallback } from "react";
import Link from "next/link";
import Sidebar from "@/components/Sidebar";
import Badge from "@/components/Badge";
import Pagination from "@/components/Pagination";
import { getUsers, UserListResponse } from "@/lib/api";

export default function UsersPage() {
  const [data, setData] = useState<UserListResponse | null>(null);
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState("");
  const [roleFilter, setRoleFilter] = useState("");
  const [error, setError] = useState("");

  const load = useCallback(() => {
    setError("");
    getUsers({ page, status: statusFilter || undefined, role: roleFilter || undefined, search: search || undefined })
      .then(setData)
      .catch((e) => setError(e.message));
  }, [page, statusFilter, roleFilter, search]);

  useEffect(() => { load(); }, [load]);

  return (
    <div className="ml-64 min-h-screen">
      <Sidebar />
      <div className="p-8">
        <h2 className="text-2xl font-bold text-misk-900 mb-6">Users</h2>

        {/* Filters */}
        <div className="flex flex-wrap gap-3 mb-6">
          <input
            type="text"
            placeholder="Search phone or email..."
            value={search}
            onChange={(e) => { setSearch(e.target.value); setPage(1); }}
            className="px-3 py-2 border rounded-lg text-sm w-64 focus:ring-2 focus:ring-gold-400 outline-none"
          />
          <select value={statusFilter} onChange={(e) => { setStatusFilter(e.target.value); setPage(1); }} className="px-3 py-2 border rounded-lg text-sm">
            <option value="">All Statuses</option>
            <option value="active">Active</option>
            <option value="pending">Pending</option>
            <option value="banned">Banned</option>
            <option value="suspended">Suspended</option>
          </select>
          <select value={roleFilter} onChange={(e) => { setRoleFilter(e.target.value); setPage(1); }} className="px-3 py-2 border rounded-lg text-sm">
            <option value="">All Roles</option>
            <option value="user">User</option>
            <option value="admin">Admin</option>
          </select>
        </div>

        {error && <div className="bg-red-50 text-red-700 rounded-lg p-4 mb-4">{error}</div>}

        {/* Table */}
        <div className="bg-white rounded-xl shadow-sm overflow-hidden">
          <table className="w-full text-sm">
            <thead>
              <tr className="bg-gray-50 text-left text-gray-600 font-medium">
                <th className="px-4 py-3">Phone</th>
                <th className="px-4 py-3">Gender</th>
                <th className="px-4 py-3">Status</th>
                <th className="px-4 py-3">Role</th>
                <th className="px-4 py-3">Tier</th>
                <th className="px-4 py-3">Joined</th>
                <th className="px-4 py-3">Last Seen</th>
              </tr>
            </thead>
            <tbody className="divide-y">
              {data?.users.map((u) => (
                <tr key={u.id} className="hover:bg-gray-50 transition-colors">
                  <td className="px-4 py-3">
                    <Link href={`/users/${u.id}`} className="text-misk-600 hover:text-misk-800 font-medium">
                      {u.phone}
                    </Link>
                    {u.email && <p className="text-xs text-gray-400">{u.email}</p>}
                  </td>
                  <td className="px-4 py-3 capitalize">{u.gender}</td>
                  <td className="px-4 py-3"><Badge value={u.status} /></td>
                  <td className="px-4 py-3"><Badge value={u.role} /></td>
                  <td className="px-4 py-3 capitalize">{u.subscription_tier}</td>
                  <td className="px-4 py-3 text-gray-500">{new Date(u.created_at).toLocaleDateString()}</td>
                  <td className="px-4 py-3 text-gray-500">{u.last_seen_at ? new Date(u.last_seen_at).toLocaleDateString() : "—"}</td>
                </tr>
              ))}
              {data?.users.length === 0 && (
                <tr><td colSpan={7} className="px-4 py-8 text-center text-gray-400">No users found</td></tr>
              )}
            </tbody>
          </table>
        </div>

        {data && <Pagination page={data.page} total={data.total} pageSize={data.page_size} onChange={setPage} />}
      </div>
    </div>
  );
}
