"use client";

import { useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import Sidebar from "@/components/Sidebar";
import Badge from "@/components/Badge";
import { getUserDetail, updateUserStatus, updateUserRole, UserDetail } from "@/lib/api";

export default function UserDetailPage() {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();
  const [data, setData] = useState<UserDetail | null>(null);
  const [error, setError] = useState("");
  const [actionMsg, setActionMsg] = useState("");

  useEffect(() => {
    getUserDetail(id).then(setData).catch((e) => setError(e.message));
  }, [id]);

  async function handleStatusChange(newStatus: string) {
    const reason = newStatus === "banned" ? prompt("Ban reason:") : undefined;
    if (newStatus === "banned" && !reason) return;
    try {
      const res = await updateUserStatus(id, newStatus, reason || undefined);
      setActionMsg(res.message);
      setData((prev) => prev ? { ...prev, user: { ...prev.user, status: newStatus } } : prev);
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Failed");
    }
  }

  async function handleRoleChange(newRole: string) {
    try {
      const res = await updateUserRole(id, newRole);
      setActionMsg(res.message);
      setData((prev) => prev ? { ...prev, user: { ...prev.user, role: newRole } } : prev);
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Failed");
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

  const { user, profile, matches, reports } = data;

  return (
    <div className="ml-64 min-h-screen">
      <Sidebar />
      <div className="p-8">
        {/* Header */}
        <button onClick={() => router.back()} className="text-sm text-misk-600 hover:text-misk-800 mb-4 inline-block">&larr; Back to Users</button>
        <h2 className="text-2xl font-bold text-misk-900 mb-1">{user.phone}</h2>
        <p className="text-sm text-gray-500 mb-6">ID: {user.id}</p>

        {actionMsg && <div className="bg-emerald-50 text-emerald-700 rounded-lg p-3 mb-4 text-sm">{actionMsg}</div>}

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* User info */}
          <div className="bg-white rounded-xl shadow-sm p-6 lg:col-span-2">
            <h3 className="text-sm font-semibold text-gray-700 mb-4">Account</h3>
            <div className="grid grid-cols-2 gap-4 text-sm">
              <Field label="Status"><Badge value={user.status} /></Field>
              <Field label="Role"><Badge value={user.role} /></Field>
              <Field label="Gender" value={user.gender} />
              <Field label="Tier" value={user.subscription_tier} />
              <Field label="Phone Verified" value={user.phone_verified ? "Yes" : "No"} />
              <Field label="Onboarding" value={user.onboarding_completed ? "Complete" : "Incomplete"} />
              <Field label="Joined" value={new Date(user.created_at).toLocaleString()} />
              <Field label="Last Seen" value={user.last_seen_at ? new Date(user.last_seen_at).toLocaleString() : "—"} />
            </div>

            {profile && (
              <>
                <h3 className="text-sm font-semibold text-gray-700 mt-6 mb-4">Profile</h3>
                <div className="grid grid-cols-2 gap-4 text-sm">
                  <Field label="Name" value={[profile.first_name, profile.last_name].filter(Boolean).join(" ") || "—"} />
                  <Field label="Location" value={[profile.city, profile.country].filter(Boolean).join(", ") || "—"} />
                  <Field label="Madhab" value={profile.madhab || "—"} />
                  <Field label="Prayer" value={profile.prayer_frequency || "—"} />
                  <Field label="Trust Score" value={String(profile.trust_score)} />
                  {profile.bio && <div className="col-span-2"><span className="text-gray-500">Bio:</span> <span className="text-gray-700">{profile.bio}</span></div>}
                </div>
              </>
            )}
          </div>

          {/* Actions */}
          <div className="space-y-4">
            <div className="bg-white rounded-xl shadow-sm p-6">
              <h3 className="text-sm font-semibold text-gray-700 mb-3">Actions</h3>
              <div className="space-y-2">
                <label className="block text-xs text-gray-500">Change Status</label>
                <select
                  value={user.status}
                  onChange={(e) => handleStatusChange(e.target.value)}
                  className="w-full px-3 py-2 border rounded-lg text-sm"
                >
                  <option value="active">Active</option>
                  <option value="pending">Pending</option>
                  <option value="suspended">Suspended</option>
                  <option value="banned">Banned</option>
                </select>
              </div>
              <div className="space-y-2 mt-4">
                <label className="block text-xs text-gray-500">Change Role</label>
                <select
                  value={user.role}
                  onChange={(e) => handleRoleChange(e.target.value)}
                  className="w-full px-3 py-2 border rounded-lg text-sm"
                >
                  <option value="user">User</option>
                  <option value="admin">Admin</option>
                </select>
              </div>
            </div>
          </div>
        </div>

        {/* Matches */}
        {matches.length > 0 && (
          <div className="mt-6 bg-white rounded-xl shadow-sm p-6">
            <h3 className="text-sm font-semibold text-gray-700 mb-4">Matches ({matches.length})</h3>
            <table className="w-full text-sm">
              <thead><tr className="text-left text-gray-500"><th className="pb-2">Other User</th><th className="pb-2">Status</th><th className="pb-2">Score</th><th className="pb-2">Date</th></tr></thead>
              <tbody className="divide-y">
                {matches.map((m) => (
                  <tr key={m.id}>
                    <td className="py-2">{m.other_user_phone}</td>
                    <td className="py-2"><Badge value={m.status} /></td>
                    <td className="py-2">{m.compatibility_score ? `${(m.compatibility_score * 100).toFixed(0)}%` : "—"}</td>
                    <td className="py-2 text-gray-500">{new Date(m.created_at).toLocaleDateString()}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {/* Reports */}
        {reports.length > 0 && (
          <div className="mt-6 bg-white rounded-xl shadow-sm p-6">
            <h3 className="text-sm font-semibold text-gray-700 mb-4">Reports ({reports.length})</h3>
            <table className="w-full text-sm">
              <thead><tr className="text-left text-gray-500"><th className="pb-2">Reason</th><th className="pb-2">Role</th><th className="pb-2">Status</th><th className="pb-2">Other User</th><th className="pb-2">Date</th></tr></thead>
              <tbody className="divide-y">
                {reports.map((r) => (
                  <tr key={r.id}>
                    <td className="py-2">{r.reason}</td>
                    <td className="py-2 capitalize">{r.role}</td>
                    <td className="py-2"><Badge value={r.status} /></td>
                    <td className="py-2">{r.other_user_phone}</td>
                    <td className="py-2 text-gray-500">{new Date(r.created_at).toLocaleDateString()}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}

function Field({ label, value, children }: { label: string; value?: string; children?: React.ReactNode }) {
  return (
    <div>
      <span className="text-gray-500">{label}:</span>{" "}
      {children || <span className="text-gray-800 capitalize">{value}</span>}
    </div>
  );
}
