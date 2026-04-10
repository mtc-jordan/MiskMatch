"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { AreaChart, Area, XAxis, YAxis, Tooltip, ResponsiveContainer } from "recharts";
import Sidebar from "@/components/Sidebar";
import StatCard from "@/components/StatCard";
import { getDashboard, getAnalytics, DashboardOverview, Analytics } from "@/lib/api";
import { useAuth } from "@/lib/auth";

export default function DashboardPage() {
  const { token } = useAuth();
  const router = useRouter();
  const [stats, setStats] = useState<DashboardOverview | null>(null);
  const [analytics, setAnalytics] = useState<Analytics | null>(null);
  const [error, setError] = useState("");

  useEffect(() => {
    if (!token && typeof window !== "undefined" && !localStorage.getItem("admin_token")) {
      router.push("/login");
      return;
    }
    Promise.all([getDashboard(), getAnalytics(30)])
      .then(([d, a]) => { setStats(d); setAnalytics(a); })
      .catch((e) => setError(e.message));
  }, [token, router]);

  if (error) {
    return (
      <div className="ml-64 p-8">
        <Sidebar />
        <div className="bg-red-50 text-red-700 rounded-lg p-4">{error}</div>
      </div>
    );
  }

  if (!stats || !analytics) {
    return (
      <div className="ml-64 p-8">
        <Sidebar />
        <div className="animate-pulse space-y-4">
          <div className="h-8 bg-gray-200 rounded w-48" />
          <div className="grid grid-cols-4 gap-4">
            {[...Array(4)].map((_, i) => <div key={i} className="h-28 bg-gray-200 rounded-xl" />)}
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="ml-64 min-h-screen">
      <Sidebar />

      <div className="p-8">
        <h2 className="text-2xl font-bold text-misk-900 mb-6">Dashboard</h2>

        {/* KPI cards */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
          <StatCard label="Total Users" value={stats.total_users} accent="default" />
          <StatCard label="Active Matches" value={stats.active_matches} accent="green" />
          <StatCard label="Messages Today" value={stats.messages_today} accent="default" />
          <StatCard label="Pending Reports" value={stats.reports_pending} accent={stats.reports_pending > 0 ? "red" : "default"} />
        </div>

        {/* Secondary stats */}
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-4 mb-8">
          <StatCard label="Active Users" value={stats.active_users} accent="green" />
          <StatCard label="Pending Users" value={stats.pending_users} accent="amber" />
          <StatCard label="Banned Users" value={stats.banned_users} accent="red" />
          <StatCard label="Total Matches" value={stats.total_matches} />
        </div>

        {/* Charts row */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
          {/* Registration chart */}
          <div className="bg-white rounded-xl shadow-sm p-6">
            <h3 className="text-sm font-semibold text-gray-700 mb-4">Registrations (Last 30 Days)</h3>
            <div className="h-64">
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={analytics.registrations_over_time}>
                  <defs>
                    <linearGradient id="regGrad" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#8B7355" stopOpacity={0.3} />
                      <stop offset="95%" stopColor="#8B7355" stopOpacity={0} />
                    </linearGradient>
                  </defs>
                  <XAxis dataKey="date" tick={{ fontSize: 11 }} />
                  <YAxis allowDecimals={false} tick={{ fontSize: 11 }} />
                  <Tooltip />
                  <Area type="monotone" dataKey="count" stroke="#8B7355" fill="url(#regGrad)" strokeWidth={2} />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          </div>

          {/* Key metrics */}
          <div className="bg-white rounded-xl shadow-sm p-6">
            <h3 className="text-sm font-semibold text-gray-700 mb-4">Key Metrics</h3>
            <div className="space-y-5">
              <Metric label="Match Success Rate" value={`${analytics.match_success_rate.toFixed(1)}%`} />
              <Metric label="Avg Messages/Match" value={analytics.avg_messages_per_match.toFixed(1)} />
              <Metric label="Total Nikah" value={analytics.total_nikah} />
              <Metric label="Games Played" value={analytics.total_games_played} />
              <Metric label="Active Calls Today" value={analytics.active_calls_today} />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function Metric({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="flex justify-between items-center">
      <span className="text-gray-600 text-sm">{label}</span>
      <span className="text-lg font-semibold text-misk-800">{value}</span>
    </div>
  );
}
