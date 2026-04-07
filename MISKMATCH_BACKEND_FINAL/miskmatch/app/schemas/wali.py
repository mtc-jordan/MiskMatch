"""
MiskMatch — Wali (Guardian) Schemas
Full Pydantic v2 models for the guardian system.

Two perspectives:
  WARD  — the user seeking marriage (has a wali)
  WALI  — the guardian (father, brother, uncle, imam)
"""

from datetime import datetime
from typing import Optional, List
from uuid import UUID

from pydantic import BaseModel, Field, field_validator, model_validator
import re


# ─────────────────────────────────────────────
# WARD → sets up their wali
# ─────────────────────────────────────────────

VALID_RELATIONSHIPS = {
    "father", "brother", "uncle", "grandfather",
    "male_relative", "imam", "trusted_male_guardian",
}


class WaliSetupRequest(BaseModel):
    """Ward submits details of their guardian."""
    wali_name: str = Field(
        ..., min_length=2, max_length=100,
        description="Guardian's full name",
    )
    wali_phone: str = Field(
        ..., min_length=7, max_length=20,
        description="Guardian's phone in E.164 format: +962791234567",
    )
    wali_relationship: str = Field(
        ..., description=f"One of: {', '.join(sorted(VALID_RELATIONSHIPS))}",
    )
    can_view_messages: bool = Field(
        default=False,
        description="Whether wali can read the chat (ward's choice)",
    )

    @field_validator("wali_phone")
    @classmethod
    def validate_phone(cls, v: str) -> str:
        v = v.strip()
        if not re.match(r"^\+\d{7,15}$", v):
            raise ValueError("Phone must be in E.164 format, e.g. +962791234567")
        return v

    @field_validator("wali_relationship")
    @classmethod
    def validate_relationship(cls, v: str) -> str:
        v = v.strip().lower()
        if v not in VALID_RELATIONSHIPS:
            raise ValueError(
                f"Invalid relationship. Must be one of: {', '.join(sorted(VALID_RELATIONSHIPS))}"
            )
        return v

    @field_validator("wali_name")
    @classmethod
    def validate_name(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("Wali name cannot be blank")
        return v.strip()


class WaliUpdatePermissionsRequest(BaseModel):
    """Ward updates what their wali is allowed to see/do."""
    can_view_messages: Optional[bool] = Field(
        None, description="Allow wali to read chat messages"
    )
    can_view_matches: Optional[bool] = Field(
        None, description="Allow wali to see match profiles"
    )
    can_join_calls: Optional[bool] = Field(
        None, description="Allow wali to join chaperoned video calls"
    )


class WaliInviteResendRequest(BaseModel):
    """Resend SMS invitation to wali."""
    message: Optional[str] = Field(
        None,
        max_length=200,
        description="Optional personal note to include in the SMS",
    )


# ─────────────────────────────────────────────
# WALI → accepts invitation
# ─────────────────────────────────────────────

class WaliAcceptRequest(BaseModel):
    """Wali accepts guardianship via the invitation token."""
    token: str = Field(
        ..., min_length=10,
        description="Invitation token from the SMS link",
    )
    create_account: bool = Field(
        default=False,
        description="Whether to create a platform account for this wali",
    )
    # Only required if create_account=True
    phone: Optional[str] = None
    password: Optional[str] = Field(None, min_length=8)

    @model_validator(mode="after")
    def validate_account_fields(self):
        if self.create_account:
            if not self.phone:
                raise ValueError("phone is required when create_account=True")
            if not self.password:
                raise ValueError("password is required when create_account=True")
        return self


# ─────────────────────────────────────────────
# WALI → match decisions
# ─────────────────────────────────────────────

class WaliMatchDecisionRequest(BaseModel):
    """Wali approves or declines a match for their ward."""
    decision: str = Field(
        ..., pattern="^(approve|decline)$",
        description="'approve' or 'decline'",
    )
    note: Optional[str] = Field(
        None,
        max_length=500,
        description="Optional note to the ward explaining the decision",
    )

    @field_validator("decision")
    @classmethod
    def validate_decision(cls, v: str) -> str:
        return v.lower().strip()


class WaliDeclineReasonRequest(BaseModel):
    """Extended decline with required reason (for transparency)."""
    reason: str = Field(
        ..., min_length=10, max_length=500,
        description="Required reason for declining — shown to ward",
    )
    is_permanent: bool = Field(
        default=False,
        description="Block this match permanently (not just decline this round)",
    )


# ─────────────────────────────────────────────
# RESPONSES
# ─────────────────────────────────────────────

class WaliStatusResponse(BaseModel):
    """Ward's view of their wali setup."""
    has_wali: bool
    wali_name: Optional[str]
    wali_phone: Optional[str]
    wali_relationship: Optional[str]
    wali_user_id: Optional[UUID]       # set if wali has a platform account
    is_active: bool
    invitation_sent: bool
    invitation_accepted: bool
    invited_at: Optional[datetime]
    accepted_at: Optional[datetime]
    # Permissions
    can_view_matches: bool
    can_view_messages: bool
    can_approve_matches: bool
    can_join_calls: bool
    model_config = {"from_attributes": True}


class WardSummary(BaseModel):
    """Wali's view of a single ward."""
    user_id: UUID
    name: str
    age: Optional[int]
    city: Optional[str]
    country: Optional[str]
    photo_url: Optional[str]
    trust_score: int
    active_matches: int
    pending_decisions: int       # matches waiting for this wali's approval
    flagged_messages: int        # AI-flagged messages across all matches
    relationship: str            # father, brother, etc.
    member_since: datetime
    model_config = {"from_attributes": True}


class PendingMatchDecision(BaseModel):
    """A match waiting for wali approval."""
    match_id: UUID
    ward_name: str
    candidate_name: str
    candidate_city: Optional[str]
    candidate_country: Optional[str]
    candidate_madhab: Optional[str]
    candidate_prayer_frequency: Optional[str]
    candidate_trust_score: int
    compatibility_score: Optional[float]
    compatibility_breakdown: Optional[dict]
    interest_message: Optional[str]   # what the candidate wrote
    match_created_at: datetime
    days_waiting: int
    model_config = {"from_attributes": True}


class WaliDashboardResponse(BaseModel):
    """Full wali portal dashboard."""
    wali_user_id: UUID
    total_wards: int
    pending_decisions: int        # total across all wards
    active_matches: int           # total ACTIVE matches across all wards
    flagged_messages: int         # total flagged messages today
    wards: List[WardSummary]
    pending_match_decisions: List[PendingMatchDecision]
    recent_notifications: List[dict]


class WaliMatchSummaryResponse(BaseModel):
    """Wali's full view of one specific match."""
    match_id: UUID
    status: str
    ward_name: str
    candidate_name: str
    candidate_profile: dict
    compatibility_score: Optional[float]
    compatibility_breakdown: Optional[dict]
    wali_approved: Optional[bool]       # this wali's decision
    other_wali_approved: Optional[bool] # the other side's decision
    approved_at: Optional[datetime]
    message_count: int
    flagged_message_count: int
    games_completed: int
    last_activity: Optional[datetime]
    match_day: int


class WaliInviteResponse(BaseModel):
    """Response after sending an invitation."""
    invitation_sent: bool
    wali_name: str
    wali_phone: str
    message: str
    expires_in_hours: int = 72


class WaliAcceptResponse(BaseModel):
    """Response after wali accepts."""
    accepted: bool
    ward_name: str
    relationship: str
    message: str
    permissions: dict
