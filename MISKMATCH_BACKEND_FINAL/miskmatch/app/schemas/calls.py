"""
MiskMatch — Calls Schemas
Pydantic v2 models for the chaperoned calls system.
"""
from __future__ import annotations

import uuid
from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


# ─────────────────────────────────────────────
# REQUEST SCHEMAS
# ─────────────────────────────────────────────

class InitiateCallRequest(BaseModel):
    match_id:           uuid.UUID
    call_type:          str = "video_chaperoned"   # audio | video | video_chaperoned
    invite_wali:        bool = True
    scheduled_at:       Optional[datetime] = None  # None = call now
    recording_consent:  bool = False


class JoinCallRequest(BaseModel):
    """Sent by each participant when they tap Accept."""
    participant_type:   str   # "initiator" | "receiver" | "wali"


class EndCallRequest(BaseModel):
    reason: Optional[str] = None   # "completed" | "declined" | "timeout" | "network"


class ScheduleCallRequest(BaseModel):
    match_id:    uuid.UUID
    call_type:   str = "video_chaperoned"
    scheduled_at:datetime
    invite_wali: bool = True


# ─────────────────────────────────────────────
# TOKEN RESPONSE  (returned to each participant)
# ─────────────────────────────────────────────

class AgoraTokenResponse(BaseModel):
    call_id:        uuid.UUID
    channel_name:   str
    agora_token:    str
    uid:            int          # Agora UID for this user
    app_id:         str
    expires_at:     datetime
    role:           str          # "publisher" | "subscriber"


# ─────────────────────────────────────────────
# CALL RESPONSE  (general call info)
# ─────────────────────────────────────────────

class CallResponse(BaseModel):
    id:                 uuid.UUID
    match_id:           uuid.UUID
    initiator_id:       uuid.UUID
    call_type:          str
    agora_channel:      str

    # Participant state
    wali_invited:       bool
    wali_joined:        bool
    wali_approved:      Optional[bool]

    # Timing
    scheduled_at:       Optional[datetime]
    started_at:         Optional[datetime]
    ended_at:           Optional[datetime]
    duration_seconds:   Optional[int]

    status:             str   # "scheduled" | "ringing" | "active" | "ended" | "missed"

    # Token — only populated for the requesting user
    token:              Optional[AgoraTokenResponse] = None

    model_config = {"from_attributes": True}


class CallSummary(BaseModel):
    """Compact version for listing calls."""
    id:              uuid.UUID
    match_id:        uuid.UUID
    call_type:       str
    status:          str
    scheduled_at:    Optional[datetime]
    started_at:      Optional[datetime]
    duration_seconds:Optional[int]
    other_name:      Optional[str] = None


class CallHistoryResponse(BaseModel):
    calls:       list[CallSummary]
    total:       int
