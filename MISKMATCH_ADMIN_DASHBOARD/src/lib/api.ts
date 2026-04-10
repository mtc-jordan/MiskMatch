/**
 * MiskMatch Admin API client.
 * Wraps fetch with auth token and base URL handling.
 */

const API_BASE = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000/api/v1";

function getToken(): string | null {
  if (typeof window === "undefined") return null;
  return localStorage.getItem("admin_token");
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const token = getToken();
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    ...(init?.headers as Record<string, string>),
  };
  if (token) headers["Authorization"] = `Bearer ${token}`;

  const res = await fetch(`${API_BASE}${path}`, { ...init, headers });

  if (res.status === 401) {
    localStorage.removeItem("admin_token");
    window.location.href = "/login";
    throw new Error("Unauthorized");
  }

  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    throw new Error(body.detail || `API error ${res.status}`);
  }

  return res.json();
}

// ── Auth ─────────────────────────────────────────

export async function login(phone: string, password: string) {
  return request<{ access_token: string }>("/auth/login", {
    method: "POST",
    body: JSON.stringify({ phone, password }),
  });
}

// ── Dashboard ────────────────────────────────────

export interface DashboardOverview {
  total_users: number;
  active_users: number;
  pending_users: number;
  banned_users: number;
  active_matches: number;
  total_matches: number;
  messages_today: number;
  reports_pending: number;
}

export async function getDashboard() {
  return request<DashboardOverview>("/admin/dashboard");
}

export interface RegistrationPoint {
  date: string;
  count: number;
}

export interface Analytics {
  registrations_over_time: RegistrationPoint[];
  match_success_rate: number;
  avg_messages_per_match: number;
  total_nikah: number;
  total_games_played: number;
  active_calls_today: number;
}

export async function getAnalytics(days = 30) {
  return request<Analytics>(`/admin/analytics?days=${days}`);
}

// ── Users ────────────────────────────────────────

export interface UserSummary {
  id: string;
  phone: string;
  email: string | null;
  role: string;
  status: string;
  gender: string;
  phone_verified: boolean;
  onboarding_completed: boolean;
  subscription_tier: string;
  created_at: string;
  last_seen_at: string | null;
}

export interface UserListResponse {
  users: UserSummary[];
  total: number;
  page: number;
  page_size: number;
}

export async function getUsers(params: { page?: number; status?: string; role?: string; search?: string } = {}) {
  const qs = new URLSearchParams();
  if (params.page) qs.set("page", String(params.page));
  if (params.status) qs.set("status", params.status);
  if (params.role) qs.set("role", params.role);
  if (params.search) qs.set("search", params.search);
  return request<UserListResponse>(`/admin/users?${qs}`);
}

export interface UserDetail {
  user: UserSummary;
  profile: {
    first_name: string | null;
    last_name: string | null;
    city: string | null;
    country: string | null;
    bio: string | null;
    photo_url: string | null;
    trust_score: number;
    madhab: string | null;
    prayer_frequency: string | null;
  } | null;
  matches: Array<{
    id: string;
    other_user_id: string;
    other_user_phone: string;
    status: string;
    compatibility_score: number | null;
    created_at: string;
  }>;
  reports: Array<{
    id: string;
    reason: string;
    status: string;
    role: string;
    other_user_phone: string;
    created_at: string;
  }>;
}

export async function getUserDetail(userId: string) {
  return request<UserDetail>(`/admin/users/${userId}`);
}

export async function updateUserStatus(userId: string, status: string, reason?: string) {
  return request<{ user_id: string; old_status: string; new_status: string; message: string }>(
    `/admin/users/${userId}/status`,
    { method: "PUT", body: JSON.stringify({ status, reason }) },
  );
}

export async function updateUserRole(userId: string, role: string) {
  return request<{ user_id: string; old_role: string; new_role: string; message: string }>(
    `/admin/users/${userId}/role`,
    { method: "PUT", body: JSON.stringify({ role }) },
  );
}

// ── Reports ──────────────────────────────────────

export interface ReportSummary {
  id: string;
  reporter_id: string;
  reported_id: string;
  reason: string;
  description: string | null;
  evidence_urls: string[] | null;
  is_block: boolean;
  status: string;
  reviewed_by: string | null;
  reviewed_at: string | null;
  resolution: string | null;
  created_at: string;
}

export interface ReportListResponse {
  reports: ReportSummary[];
  total: number;
  page: number;
  page_size: number;
}

export async function getReports(params: { page?: number; status?: string } = {}) {
  const qs = new URLSearchParams();
  if (params.page) qs.set("page", String(params.page));
  if (params.status) qs.set("status", params.status);
  return request<ReportListResponse>(`/admin/reports?${qs}`);
}

export interface ReportDetail {
  report: ReportSummary;
  reporter: { id: string; phone: string; email: string | null; status: string; first_name: string | null; last_name: string | null };
  reported: { id: string; phone: string; email: string | null; status: string; first_name: string | null; last_name: string | null };
}

export async function getReportDetail(reportId: string) {
  return request<ReportDetail>(`/admin/reports/${reportId}`);
}

export async function resolveReport(reportId: string, action: string, note?: string) {
  return request<{ report_id: string; action: string; resolution: string; message: string }>(
    `/admin/reports/${reportId}/resolve`,
    { method: "PUT", body: JSON.stringify({ action, resolution_note: note }) },
  );
}

// ── Flagged Messages ─────────────────────────────

export interface FlaggedMessage {
  id: string;
  match_id: string;
  sender_id: string;
  sender_phone: string;
  content: string;
  content_type: string;
  moderation_reason: string | null;
  created_at: string;
}

export interface FlaggedMessageListResponse {
  messages: FlaggedMessage[];
  total: number;
  page: number;
  page_size: number;
}

export async function getFlaggedMessages(page = 1) {
  return request<FlaggedMessageListResponse>(`/admin/flagged-messages?page=${page}`);
}

// ── Matches ──────────────────────────────────────

export interface MatchSummary {
  id: string;
  sender_id: string;
  sender_phone: string;
  receiver_id: string;
  receiver_phone: string;
  status: string;
  compatibility_score: number | null;
  created_at: string;
  became_mutual_at: string | null;
  nikah_date: string | null;
  closed_reason: string | null;
}

export interface MatchListResponse {
  matches: MatchSummary[];
  total: number;
  page: number;
  page_size: number;
}

export async function getMatches(params: { page?: number; status?: string } = {}) {
  const qs = new URLSearchParams();
  if (params.page) qs.set("page", String(params.page));
  if (params.status) qs.set("status", params.status);
  return request<MatchListResponse>(`/admin/matches?${qs}`);
}

export interface MatchFunnelStats {
  total_pending: number;
  total_mutual: number;
  total_approved: number;
  total_active: number;
  total_nikah: number;
  total_closed: number;
  total_blocked: number;
  pending_to_mutual_rate: number;
  mutual_to_active_rate: number;
  active_to_nikah_rate: number;
}

export async function getMatchStats() {
  return request<MatchFunnelStats>("/admin/matches/stats");
}
