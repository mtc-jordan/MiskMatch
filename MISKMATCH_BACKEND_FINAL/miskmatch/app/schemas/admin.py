"""MiskMatch — Admin Dashboard Schemas (Pydantic v2)"""

from datetime import datetime
from typing import Optional, List
from uuid import UUID

from pydantic import BaseModel, Field

from app.models.models import UserRole, UserStatus, MatchStatus


# ─────────────────────────────────────────────
# ANALYTICS
# ─────────────────────────────────────────────

class DashboardOverview(BaseModel):
    total_users: int
    active_users: int
    pending_users: int
    banned_users: int
    active_matches: int
    total_matches: int
    messages_today: int
    reports_pending: int


class RegistrationPoint(BaseModel):
    date: str
    count: int


class AnalyticsResponse(BaseModel):
    registrations_over_time: List[RegistrationPoint]
    match_success_rate: float = Field(
        description="Percentage of matches that reached MUTUAL or beyond"
    )
    avg_messages_per_match: float
    total_nikah: int
    total_games_played: int
    active_calls_today: int


# ─────────────────────────────────────────────
# USER MANAGEMENT
# ─────────────────────────────────────────────

class AdminUserSummary(BaseModel):
    id: UUID
    phone: str
    email: Optional[str] = None
    role: UserRole
    status: UserStatus
    gender: str
    phone_verified: bool
    onboarding_completed: bool
    subscription_tier: str
    created_at: datetime
    last_seen_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


class AdminUserListResponse(BaseModel):
    users: List[AdminUserSummary]
    total: int
    page: int
    page_size: int


class AdminUserProfileDetail(BaseModel):
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    city: Optional[str] = None
    country: Optional[str] = None
    bio: Optional[str] = None
    photo_url: Optional[str] = None
    trust_score: int = 0
    madhab: Optional[str] = None
    prayer_frequency: Optional[str] = None

    model_config = {"from_attributes": True}


class AdminMatchSummary(BaseModel):
    id: UUID
    other_user_id: UUID
    other_user_phone: str
    status: MatchStatus
    compatibility_score: Optional[float] = None
    created_at: datetime


class AdminReportSummary(BaseModel):
    id: UUID
    reason: str
    status: str
    role: str = Field(description="'reporter' or 'reported'")
    other_user_phone: str
    created_at: datetime


class AdminUserDetailResponse(BaseModel):
    user: AdminUserSummary
    profile: Optional[AdminUserProfileDetail] = None
    matches: List[AdminMatchSummary] = []
    reports: List[AdminReportSummary] = []


class UpdateUserStatusRequest(BaseModel):
    status: UserStatus
    reason: Optional[str] = None


class UpdateUserStatusResponse(BaseModel):
    user_id: UUID
    old_status: UserStatus
    new_status: UserStatus
    message: str


class UpdateUserRoleRequest(BaseModel):
    role: UserRole


class UpdateUserRoleResponse(BaseModel):
    user_id: UUID
    old_role: UserRole
    new_role: UserRole
    message: str


# ─────────────────────────────────────────────
# MODERATION — REPORTS
# ─────────────────────────────────────────────

class ReportResponse(BaseModel):
    id: UUID
    reporter_id: UUID
    reported_id: UUID
    reason: str
    description: Optional[str] = None
    evidence_urls: Optional[List[str]] = None
    is_block: bool
    status: str
    reviewed_by: Optional[UUID] = None
    reviewed_at: Optional[datetime] = None
    resolution: Optional[str] = None
    created_at: datetime

    model_config = {"from_attributes": True}


class ReportListResponse(BaseModel):
    reports: List[ReportResponse]
    total: int
    page: int
    page_size: int


class ReportDetailUser(BaseModel):
    id: UUID
    phone: str
    email: Optional[str] = None
    status: UserStatus
    first_name: Optional[str] = None
    last_name: Optional[str] = None


class ReportDetailResponse(BaseModel):
    report: ReportResponse
    reporter: ReportDetailUser
    reported: ReportDetailUser


class ResolveReportRequest(BaseModel):
    action: str = Field(
        description="One of: warn, ban, dismiss"
    )
    resolution_note: Optional[str] = None


class ResolveReportResponse(BaseModel):
    report_id: UUID
    action: str
    resolution: str
    message: str


# ─────────────────────────────────────────────
# FLAGGED MESSAGES
# ─────────────────────────────────────────────

class FlaggedMessageResponse(BaseModel):
    id: UUID
    match_id: UUID
    sender_id: UUID
    sender_phone: str
    content: str
    content_type: str
    moderation_reason: Optional[str] = None
    created_at: datetime

    model_config = {"from_attributes": True}


class FlaggedMessageListResponse(BaseModel):
    messages: List[FlaggedMessageResponse]
    total: int
    page: int
    page_size: int


# ─────────────────────────────────────────────
# MATCH MANAGEMENT
# ─────────────────────────────────────────────

class AdminMatchResponse(BaseModel):
    id: UUID
    sender_id: UUID
    sender_phone: str
    receiver_id: UUID
    receiver_phone: str
    status: MatchStatus
    compatibility_score: Optional[float] = None
    created_at: datetime
    became_mutual_at: Optional[datetime] = None
    nikah_date: Optional[datetime] = None
    closed_reason: Optional[str] = None

    model_config = {"from_attributes": True}


class AdminMatchListResponse(BaseModel):
    matches: List[AdminMatchResponse]
    total: int
    page: int
    page_size: int


class MatchFunnelStats(BaseModel):
    total_pending: int
    total_mutual: int
    total_approved: int
    total_active: int
    total_nikah: int
    total_closed: int
    total_blocked: int
    pending_to_mutual_rate: float
    mutual_to_active_rate: float
    active_to_nikah_rate: float
