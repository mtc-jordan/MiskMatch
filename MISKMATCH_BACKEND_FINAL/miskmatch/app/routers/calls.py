"""
MiskMatch — Calls Router
Chaperoned 3-way video/audio call system using Agora RTC.

Endpoints:
  POST /calls/initiate              Start or schedule a new call
  POST /calls/{call_id}/join        Join an existing call (get Agora token)
  POST /calls/{call_id}/end         End an active call
  GET  /calls/{call_id}             Get call details + token refresh
  GET  /calls/match/{match_id}      Call history for a match
  POST /calls/{call_id}/wali-approve Wali approves joining a call
  GET  /calls/active                My currently active call (if any)

Islamic constraint:
  VIDEO_CHAPERONED calls require both walis to have approved the match.
  The wali always has the option to join as subscriber (listen/observe)
  or, if they choose, unmute and speak. They cannot be removed once invited.
"""
from __future__ import annotations

import uuid
import logging
from typing import Annotated, Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select, and_, or_
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.models.models import Call, Match, User, MatchStatus
from app.routers.auth import get_current_active_user
from app.schemas.calls import (
    InitiateCallRequest, JoinCallRequest, EndCallRequest,
    ScheduleCallRequest, CallResponse, CallHistoryResponse, CallSummary,
)
from app.services.calls import (
    initiate_call, join_call, end_call,
    get_call_history, serialise_call, call_status,
)

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/calls", tags=["Chaperoned Calls"])

CurrentUser = Annotated[User, Depends(get_current_active_user)]
DB          = Annotated[AsyncSession, Depends(get_db)]


# ─────────────────────────────────────────────
# POST /calls/initiate
# ─────────────────────────────────────────────

@router.post(
    "/initiate",
    response_model=CallResponse,
    summary="Initiate or schedule a chaperoned call",
    description="""
Start a new call immediately or schedule one for the future.

**Call types:**
- `video_chaperoned` — 3-way video with wali (default, required for first call)
- `video` — direct video (only after ≥3 chaperoned calls)
- `audio` — audio only

**Islamic rules enforced:**
- Both guardians must have approved the match
- No private unchaperoned video/audio until the couple have had ≥3 wali calls
- Wali is always invited and notified

**Immediate call:** `scheduled_at = null` → call opens immediately, push sent to receiver + wali  
**Scheduled call:** `scheduled_at` set → reminder sent 15 minutes before
    """,
)
async def initiate(
    req:          InitiateCallRequest,
    current_user: CurrentUser,
    db:           DB,
):
    try:
        call, token = await initiate_call(db, current_user, req)
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))

    return serialise_call(call, token)


# ─────────────────────────────────────────────
# POST /calls/{call_id}/join
# ─────────────────────────────────────────────

@router.post(
    "/{call_id}/join",
    response_model=CallResponse,
    summary="Join a call — get Agora token",
    description="""
Join an existing call as receiver or wali.
Returns the caller's unique Agora token for the call channel.

**participant_type values:**
- `receiver`   — the other person in the match
- `wali`       — guardian joining as chaperone (subscriber role by default)
- `initiator`  — rare: initiator device switch / token refresh

The wali always joins as **subscriber** (can see and hear, microphone muted by default).
They can unmute from within the app — this is their choice as guardian.

Token expiry: 1 hour. If call is still active, call this endpoint again to refresh.
    """,
)
async def join(
    call_id:      uuid.UUID,
    req:          JoinCallRequest,
    current_user: CurrentUser,
    db:           DB,
):
    try:
        call, token = await join_call(
            db, call_id, current_user, req.participant_type)
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))

    return serialise_call(call, token)


# ─────────────────────────────────────────────
# POST /calls/{call_id}/end
# ─────────────────────────────────────────────

@router.post(
    "/{call_id}/end",
    response_model=CallResponse,
    summary="End an active call",
    description="""
End a call. Any participant (initiator, receiver, or wali) can end the call.

The call record is updated with:
- `ended_at` timestamp
- `duration_seconds` (calculated from started_at)
- `reason` stored in logs

A missed call (never answered) has `duration_seconds = 0`.
    """,
)
async def end(
    call_id:      uuid.UUID,
    req:          EndCallRequest,
    current_user: CurrentUser,
    db:           DB,
):
    try:
        call = await end_call(db, call_id, current_user, req.reason)
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))

    return serialise_call(call)


# ─────────────────────────────────────────────
# GET /calls/{call_id}
# ─────────────────────────────────────────────

@router.get(
    "/{call_id}",
    response_model=CallResponse,
    summary="Get call details",
    description="Returns call status and a fresh token if the call is still active.",
)
async def get_call(
    call_id:      uuid.UUID,
    current_user: CurrentUser,
    db:           DB,
):
    call_result = await db.execute(
        select(Call).where(Call.id == call_id)
    )
    call = call_result.scalar_one_or_none()
    if not call:
        raise HTTPException(status_code=404, detail="Call not found.")

    # Verify user is a participant
    match_result = await db.execute(
        select(Match).where(
            and_(
                Match.id == call.match_id,
                or_(
                    Match.sender_id   == current_user.id,
                    Match.receiver_id == current_user.id,
                ),
            )
        )
    )
    if not match_result.scalar_one_or_none():
        raise HTTPException(
            status_code=403, detail="You are not a participant in this call.")

    return serialise_call(call)


# ─────────────────────────────────────────────
# GET /calls/match/{match_id}
# ─────────────────────────────────────────────

@router.get(
    "/match/{match_id}",
    response_model=CallHistoryResponse,
    summary="Call history for a match",
)
async def match_call_history(
    match_id:     uuid.UUID,
    current_user: CurrentUser,
    db:           DB,
    limit:  int   = Query(default=20, ge=1, le=100),
    offset: int   = Query(default=0, ge=0),
):
    # Verify access to match
    match_result = await db.execute(
        select(Match).where(
            and_(
                Match.id == match_id,
                or_(
                    Match.sender_id   == current_user.id,
                    Match.receiver_id == current_user.id,
                ),
            )
        )
    )
    if not match_result.scalar_one_or_none():
        raise HTTPException(
            status_code=403, detail="Match not found or access denied.")

    calls, total = await get_call_history(
        db, current_user, match_id=match_id, limit=limit, offset=offset)

    summaries = [
        CallSummary(
            id               = c.id,
            match_id         = c.match_id,
            call_type        = c.call_type.value,
            status           = call_status(c),
            scheduled_at     = c.scheduled_at,
            started_at       = c.started_at,
            duration_seconds = c.duration_seconds,
        )
        for c in calls
    ]

    return CallHistoryResponse(calls=summaries, total=total)


# ─────────────────────────────────────────────
# GET /calls/active
# ─────────────────────────────────────────────

@router.get(
    "/active",
    response_model=Optional[CallResponse],
    summary="Get my currently active call",
    description="Returns the active call if one exists, or null. Used on app open to reconnect.",
)
async def get_active_call(
    current_user: CurrentUser,
    db:           DB,
):
    result = await db.execute(
        select(Call)
        .join(Match, Call.match_id == Match.id)
        .where(
            and_(
                or_(
                    Match.sender_id   == current_user.id,
                    Match.receiver_id == current_user.id,
                ),
                Call.started_at != None,
                Call.ended_at   == None,
            )
        )
        .order_by(Call.started_at.desc())
        .limit(1)
    )
    call = result.scalar_one_or_none()
    if not call:
        return None
    return serialise_call(call)


# ─────────────────────────────────────────────
# POST /calls/{call_id}/wali-approve
# ─────────────────────────────────────────────

@router.post(
    "/{call_id}/wali-approve",
    summary="Wali approves or declines joining a call",
    description="""
The wali can explicitly approve or decline participating in a call.
If declined, the call continues as a 2-way (non-chaperoned).
The match's `wali_call_approved` flag is updated.
    """,
)
async def wali_approve(
    call_id:      uuid.UUID,
    approved:     bool,
    current_user: CurrentUser,
    db:           DB,
):
    call_result = await db.execute(
        select(Call).where(Call.id == call_id)
    )
    call = call_result.scalar_one_or_none()
    if not call:
        raise HTTPException(status_code=404, detail="Call not found.")

    # Verify this user is actually a wali for one of the match participants
    from app.models.models import WaliRelationship
    match_result = await db.execute(
        select(Match).where(Match.id == call.match_id)
    )
    match = match_result.scalar_one_or_none()
    if not match:
        raise HTTPException(status_code=404, detail="Match not found.")

    wali_check = await db.execute(
        select(WaliRelationship).where(
            and_(
                WaliRelationship.wali_user_id == current_user.id,
                WaliRelationship.is_active == True,
                or_(
                    WaliRelationship.user_id == match.sender_id,
                    WaliRelationship.user_id == match.receiver_id,
                ),
            )
        )
    )
    if not wali_check.scalar_one_or_none():
        raise HTTPException(
            status_code=403,
            detail="Only a registered guardian can approve calls.",
        )

    call.wali_approved = approved
    await db.commit()

    return {
        "call_id":   str(call_id),
        "approved":  approved,
        "message":   (
            "JazakAllah Khair — guardian has approved this call."
            if approved
            else "Guardian has declined. Call may proceed without wali."
        ),
    }
