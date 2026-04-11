"""
MiskMatch — Calls Service
Agora RTC chaperoned call system.

Architecture:
  - 3-way chaperoned calls: ward (A) + candidate (B) + wali (C)
  - Wali joins as subscriber by default (can mute/observe)
  - Wali can promote themselves to publisher (speak)
  - Islamic principle: no private voice/video before nikah
  - Both walis can be invited (optional — controlled by permissions)

Agora Token Flow:
  1. Initiator calls POST /calls/initiate
  2. Server creates Call record + generates channel name
  3. Server generates token for initiator (role=publisher)
  4. Server sends push notification to receiver + wali
  5. Receiver calls POST /calls/{id}/join → gets their token
  6. Wali calls POST /calls/{id}/join → gets subscriber token
  7. All 3 connect to same Agora channel
  8. Anyone calls POST /calls/{id}/end to end the call

Token expiry: 3600 seconds (1 hour max call duration)
Channel naming: miskmatch_{call_id_short} — unique per call
"""
from __future__ import annotations

import hashlib
import logging
import math
import time
import uuid
from datetime import datetime, timezone, timedelta
from typing import Optional

from sqlalchemy import select, and_, or_
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.models import (
    Call, CallType, Match, MatchStatus, User,
    WaliRelationship,
)
from app.schemas.calls import (
    AgoraTokenResponse, CallResponse, InitiateCallRequest,
)

logger = logging.getLogger(__name__)

# Call duration limits
MAX_CALL_SECONDS = 3600    # 1 hour
TOKEN_EXPIRY     = 3600    # 1 hour

# Agora UID ranges (must be uint32, non-zero)
UID_INITIATOR = 1001
UID_RECEIVER  = 1002
UID_WALI      = 1003


# ─────────────────────────────────────────────
# AGORA TOKEN GENERATION
# ─────────────────────────────────────────────

def generate_agora_token(
    channel_name: str,
    uid: int,
    role_publisher: bool = True,
    expiry_seconds: int  = TOKEN_EXPIRY,
) -> str:
    """
    Generate an Agora RTC token using agora-token-builder.

    Falls back to a deterministic dev token when AGORA_APP_ID / AGORA_APP_CERT
    are not configured (safe for local dev — Agora SDK accepts unsigned tokens
    in testing mode when app certificate is empty).
    """
    app_id   = getattr(settings, "AGORA_APP_ID",   None) or ""
    app_cert = getattr(settings, "AGORA_APP_CERT",  None) or ""

    if not app_id or not app_cert:
        if settings.is_production:
            raise RuntimeError("Agora credentials required in production (AGORA_APP_ID, AGORA_APP_CERT)")
        logger.debug("Agora: no credentials — using dev token")
        return _dev_token(channel_name, uid)

    try:
        from agora_token_builder import RtcTokenBuilder
        role = 1 if role_publisher else 2   # 1=publisher, 2=subscriber
        expire_ts = int(time.time()) + expiry_seconds
        token = RtcTokenBuilder.buildTokenWithUid(
            app_id, app_cert, channel_name, uid, role, expire_ts
        )
        logger.info(
            f"Agora token generated: channel={channel_name} uid={uid} role={'pub' if role_publisher else 'sub'}"
        )
        return token
    except (ImportError, ValueError, OSError) as e:
        logger.error(f"Agora token generation failed ({type(e).__name__}): {e}")
        return _dev_token(channel_name, uid)


def _dev_token(channel_name: str, uid: int) -> str:
    """Deterministic placeholder token for development without Agora credentials."""
    h = hashlib.sha256(f"{channel_name}:{uid}".encode()).hexdigest()[:32]
    return f"dev_token_{h}"


def make_channel_name(call_id: uuid.UUID) -> str:
    """Create a unique, short Agora channel name from the call UUID."""
    short = str(call_id).replace("-", "")[:20]
    return f"misk_{short}"


# ─────────────────────────────────────────────
# CALL STATUS HELPER
# ─────────────────────────────────────────────

def call_status(call: Call) -> str:
    if call.ended_at:
        dur = call.duration_seconds or 0
        return "missed" if dur == 0 else "ended"
    if call.started_at:
        return "active"
    if call.scheduled_at and call.scheduled_at > datetime.now(timezone.utc):
        return "scheduled"
    return "ringing"


# ─────────────────────────────────────────────
# INITIATE CALL
# ─────────────────────────────────────────────

async def initiate_call(
    db:         AsyncSession,
    initiator:  User,
    req:        InitiateCallRequest,
) -> tuple[Call, AgoraTokenResponse]:
    """
    Create a new call record and return the initiator's Agora token.
    Validates the match is ACTIVE and both walis have approved.
    """
    # ── Verify match ──────────────────────────────────────────────────────────
    match_result = await db.execute(
        select(Match).where(
            and_(
                Match.id == req.match_id,
                Match.status == MatchStatus.ACTIVE,
                or_(
                    Match.sender_id   == initiator.id,
                    Match.receiver_id == initiator.id,
                ),
            )
        )
    )
    match = match_result.scalar_one_or_none()
    if not match:
        raise ValueError("Match not found or not active.")

    # Require both walis approved for chaperoned calls
    if req.call_type == CallType.VIDEO_CHAPERONED:
        if not (match.sender_wali_approved and match.receiver_wali_approved):
            raise ValueError(
                "Both guardians must approve before a chaperoned call can begin."
            )

    # ── Prevent overlapping active calls ──────────────────────────────────────
    active_result = await db.execute(
        select(Call).where(
            and_(
                Call.match_id   == req.match_id,
                Call.ended_at   == None,
                Call.started_at != None,
            )
        )
    )
    if active_result.scalar_one_or_none():
        raise ValueError("A call is already active for this match.")

    # ── Create call record ────────────────────────────────────────────────────
    call_id      = uuid.uuid4()
    channel_name = make_channel_name(call_id)

    call = Call(
        id              = call_id,
        match_id        = req.match_id,
        initiator_id    = initiator.id,
        call_type       = CallType(req.call_type),
        agora_channel   = channel_name,
        wali_invited    = req.invite_wali,
        wali_joined     = False,
        scheduled_at    = req.scheduled_at,
        started_at      = None if req.scheduled_at else datetime.now(timezone.utc),
        recording_consent = req.recording_consent,
    )
    db.add(call)
    await db.commit()
    await db.refresh(call)

    # ── Generate initiator token ───────────────────────────────────────────────
    expires_at = datetime.now(timezone.utc) + timedelta(seconds=TOKEN_EXPIRY)
    token_str  = generate_agora_token(
        channel_name  = channel_name,
        uid           = UID_INITIATOR,
        role_publisher= True,
        expiry_seconds= TOKEN_EXPIRY,
    )

    token_resp = AgoraTokenResponse(
        call_id      = call.id,
        channel_name = channel_name,
        agora_token  = token_str,
        uid          = UID_INITIATOR,
        app_id       = getattr(settings, "AGORA_APP_ID", "dev_app_id"),
        expires_at   = expires_at,
        role         = "publisher",
    )

    logger.info(
        f"Call initiated: id={call.id} match={req.match_id} "
        f"type={req.call_type} initiator={initiator.id}"
    )
    return call, token_resp


# ─────────────────────────────────────────────
# JOIN CALL
# ─────────────────────────────────────────────

async def join_call(
    db:          AsyncSession,
    call_id:     uuid.UUID,
    joiner:      User,
    participant_type: str,   # "initiator" | "receiver" | "wali"
) -> tuple[Call, AgoraTokenResponse]:
    """
    Join an existing call. Determines the correct Agora UID and role,
    marks the call as started if first receiver joins.
    """
    call_result = await db.execute(
        select(Call).where(Call.id == call_id)
    )
    call = call_result.scalar_one_or_none()
    if not call:
        raise ValueError("Call not found.")
    if call.ended_at:
        raise ValueError("This call has already ended.")

    # Determine UID and publisher role
    uid_map = {
        "initiator": (UID_INITIATOR, True),
        "receiver":  (UID_RECEIVER,  True),
        "wali":      (UID_WALI,      False),  # wali joins as subscriber
    }
    uid, is_publisher = uid_map.get(participant_type, (UID_WALI, False))

    # Mark call as started when receiver joins (if not already started)
    if participant_type == "receiver" and not call.started_at:
        call.started_at = datetime.now(timezone.utc)

    # Mark wali joined
    if participant_type == "wali":
        call.wali_joined = True

    await db.commit()
    await db.refresh(call)

    expires_at = datetime.now(timezone.utc) + timedelta(seconds=TOKEN_EXPIRY)
    token_str  = generate_agora_token(
        channel_name   = call.agora_channel,
        uid            = uid,
        role_publisher = is_publisher,
        expiry_seconds = TOKEN_EXPIRY,
    )

    token_resp = AgoraTokenResponse(
        call_id      = call.id,
        channel_name = call.agora_channel,
        agora_token  = token_str,
        uid          = uid,
        app_id       = getattr(settings, "AGORA_APP_ID", "dev_app_id"),
        expires_at   = expires_at,
        role         = "publisher" if is_publisher else "subscriber",
    )

    logger.info(
        f"Call joined: id={call_id} participant={participant_type} uid={uid}"
    )
    return call, token_resp


# ─────────────────────────────────────────────
# END CALL
# ─────────────────────────────────────────────

async def end_call(
    db:      AsyncSession,
    call_id: uuid.UUID,
    ender:   User,
    reason:  Optional[str] = None,
) -> Call:
    """
    End a call. Calculates duration. Any participant can end the call.
    """
    call_result = await db.execute(
        select(Call).where(Call.id == call_id)
    )
    call = call_result.scalar_one_or_none()
    if not call:
        raise ValueError("Call not found.")
    if call.ended_at:
        raise ValueError("Call already ended.")

    now            = datetime.now(timezone.utc)
    call.ended_at  = now

    if call.started_at:
        started = call.started_at
        if started.tzinfo is None:
            started = started.replace(tzinfo=timezone.utc)
        call.duration_seconds = max(0, int((now - started).total_seconds()))
    else:
        call.duration_seconds = 0

    await db.commit()
    await db.refresh(call)

    logger.info(
        f"Call ended: id={call_id} duration={call.duration_seconds}s reason={reason}"
    )
    return call


# ─────────────────────────────────────────────
# GET CALL HISTORY
# ─────────────────────────────────────────────

async def get_call_history(
    db:       AsyncSession,
    user:     User,
    match_id: Optional[uuid.UUID] = None,
    limit:    int = 20,
    offset:   int = 0,
) -> tuple[list[Call], int]:
    """Return calls the user participated in."""
    stmt = (
        select(Call)
        .join(Match, Call.match_id == Match.id)
        .where(
            or_(
                Match.sender_id   == user.id,
                Match.receiver_id == user.id,
            )
        )
        .order_by(Call.started_at.desc().nullsfirst())
        .limit(limit)
        .offset(offset)
    )
    if match_id:
        stmt = stmt.where(Call.match_id == match_id)

    result = await db.execute(stmt)
    calls  = result.scalars().all()
    return list(calls), len(calls)


# ─────────────────────────────────────────────
# SERIALISE CALL
# ─────────────────────────────────────────────

def serialise_call(
    call:  Call,
    token: Optional[AgoraTokenResponse] = None,
) -> CallResponse:
    return CallResponse(
        id               = call.id,
        match_id         = call.match_id,
        initiator_id     = call.initiator_id,
        call_type        = call.call_type.value,
        agora_channel    = call.agora_channel,
        wali_invited     = call.wali_invited,
        wali_joined      = call.wali_joined,
        wali_approved    = call.wali_approved,
        scheduled_at     = call.scheduled_at,
        started_at       = call.started_at,
        ended_at         = call.ended_at,
        duration_seconds = call.duration_seconds,
        status           = call_status(call),
        token            = token,
    )
