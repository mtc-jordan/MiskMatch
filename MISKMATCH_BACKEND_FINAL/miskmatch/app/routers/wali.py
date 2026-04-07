"""
MiskMatch — Wali (Guardian) Router
Full guardian portal with two complementary perspectives.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
WARD ENDPOINTS  (user seeking marriage)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
POST   /wali/setup                     Register a guardian
POST   /wali/invite                    Send SMS invitation to guardian
POST   /wali/invite/resend             Resend SMS invitation
POST   /wali/accept                    Guardian accepts (alt: via token link)
GET    /wali/status                    My wali setup status
PUT    /wali/permissions               Update what wali can see/do
DELETE /wali                           Remove wali (with safety checks)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
WALI ENDPOINTS  (the guardian)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
GET    /wali/dashboard                 Full dashboard — wards, pending, flagged
GET    /wali/wards                     All wards with summaries
GET    /wali/decisions/pending         All matches awaiting this wali's decision
GET    /wali/matches/{match_id}        Full match summary for a specific match
POST   /wali/matches/{match_id}/decide Approve or decline a match
"""

import logging
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.models.models import User, UserStatus
from app.routers.auth import get_current_active_user
from app.schemas.wali import (
    WaliSetupRequest,
    WaliUpdatePermissionsRequest,
    WaliInviteResendRequest,
    WaliMatchDecisionRequest,
    WaliStatusResponse,
    WaliInviteResponse,
    WaliAcceptResponse,
)
from app.services import wali as wali_svc

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/wali", tags=["Wali — Guardian Portal"])

CurrentUser = Annotated[User, Depends(get_current_active_user)]
DB          = Annotated[AsyncSession, Depends(get_db)]


# ═══════════════════════════════════════════════
# WARD ENDPOINTS
# ═══════════════════════════════════════════════

@router.post(
    "/setup",
    status_code=status.HTTP_201_CREATED,
    summary="Register a wali (guardian)",
    description="""
Ward registers their Islamic guardian.

**Islamic context:** A wali is required for a woman's marriage in Islam.
MiskMatch supports: father, brother, uncle, grandfather, imam, or trusted male guardian.

**Cooldown:** You can change your wali once every 30 days to prevent abuse.

**Auto-link:** If the wali's phone number is already registered on MiskMatch,
their accounts are automatically linked.
    """,
)
async def setup_wali(
    body: WaliSetupRequest,
    current_user: CurrentUser,
    db: DB,
):
    try:
        wali_rel = await wali_svc.setup_wali(db, current_user.id, body)
        await db.commit()
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))

    return {
        "message":          "Wali registered successfully. Send an invitation to complete setup.",
        "wali_name":        wali_rel.wali_name,
        "wali_phone":       wali_rel.wali_phone,
        "wali_relationship":wali_rel.wali_relationship,
        "next_step":        "POST /api/v1/wali/invite to send the SMS invitation.",
    }


@router.post(
    "/invite",
    response_model=WaliInviteResponse,
    summary="Send SMS invitation to guardian",
    description="""
Sends an SMS to the registered guardian with a secure acceptance link.

The link is valid for **72 hours**. If it expires, use `/invite/resend`.

In development, the `invite_token` is returned in the response for testing.
In production, it is only sent via SMS.
    """,
)
async def send_invitation(
    current_user: CurrentUser,
    db: DB,
):
    try:
        result = await wali_svc.send_wali_invitation(db, current_user.id)
        await db.commit()
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))

    return result


@router.post(
    "/invite/resend",
    response_model=WaliInviteResponse,
    summary="Resend SMS invitation",
    description="Resend the invitation if it expired or was not received.",
)
async def resend_invitation(
    body: WaliInviteResendRequest,
    current_user: CurrentUser,
    db: DB,
):
    try:
        result = await wali_svc.send_wali_invitation(db, current_user.id)
        await db.commit()
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))

    return result


@router.post(
    "/accept",
    response_model=WaliAcceptResponse,
    summary="Accept guardianship (wali accepts invitation)",
    description="""
The guardian calls this endpoint to accept their guardianship role.

**Two flows:**
1. Guardian uses the SMS link → token is validated, account linked automatically.
2. Guardian logs in to their MiskMatch account and accepts via the app.

In both cases, the ward is notified immediately.
    """,
)
async def accept_invitation(
    current_user: CurrentUser,
    db: DB,
    ward_id: UUID = Query(..., description="The ID of the ward (from the SMS link)"),
):
    """
    Authenticated wali user accepts guardianship for a ward.
    They must be logged in as the phone number that received the invitation.
    """
    try:
        result = await wali_svc.accept_wali_invitation(
            db=db,
            wali_phone=current_user.phone,
            ward_id=ward_id,
        )
        await db.commit()
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))

    return result


@router.get(
    "/status",
    response_model=WaliStatusResponse,
    summary="Get my wali setup status",
    description="Ward checks if their wali is registered, invited, and has accepted.",
)
async def get_wali_status(
    current_user: CurrentUser,
    db: DB,
):
    result = await wali_svc.get_ward_wali_status(db, current_user.id)
    return WaliStatusResponse(has_wali=result["has_wali"], **{
        k: v for k, v in result.items() if k != "has_wali"
    })


@router.put(
    "/permissions",
    summary="Update wali permissions",
    description="""
Ward controls what their guardian is allowed to see and do.

**Defaults:**
- `can_view_matches` → True (guardian sees match candidates)
- `can_view_messages` → False (guardian does NOT see chat by default)
- `can_approve_matches` → True (guardian must approve matches)
- `can_join_calls` → True (guardian can join chaperoned video calls)

The ward can grant or revoke `can_view_messages` and `can_join_calls` at any time.
`can_approve_matches` cannot be disabled — this is a core Islamic requirement.
    """,
)
async def update_permissions(
    body: WaliUpdatePermissionsRequest,
    current_user: CurrentUser,
    db: DB,
):
    try:
        wali_rel = await wali_svc.update_wali_permissions(db, current_user.id, body)
        await db.commit()
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))

    return {
        "message": "Permissions updated.",
        "permissions": {
            "can_view_matches":    wali_rel.can_view_matches,
            "can_view_messages":   wali_rel.can_view_messages,
            "can_approve_matches": wali_rel.can_approve_matches,
            "can_join_calls":      wali_rel.can_join_calls,
        },
    }


@router.delete(
    "",
    summary="Remove wali",
    description="""
Ward removes their guardian.

**Safety gate:** Cannot remove a wali while a match is pending their approval.
The ward must wait for the decision first, or close the match manually.

After removal, you can register a new wali immediately (30-day cooldown
only applies to changing from one wali to another).
    """,
)
async def remove_wali(
    current_user: CurrentUser,
    db: DB,
    reason: str = Query(
        ..., min_length=5, max_length=500,
        description="Reason for removing wali (for audit log)",
    ),
):
    try:
        result = await wali_svc.remove_wali(db, current_user.id, reason)
        await db.commit()
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))

    return result


# ═══════════════════════════════════════════════
# WALI ENDPOINTS
# ═══════════════════════════════════════════════

@router.get(
    "/dashboard",
    summary="Wali: full portal dashboard",
    description="""
Returns the complete guardian dashboard:

- **Wards** — all users this wali is guarding
- **Pending decisions** — matches waiting for this wali's approve/decline
- **Flagged messages** — AI-moderated messages flagged today
- **Active matches** — total ACTIVE matches across all wards
- **Recent notifications** — wali-specific alerts

This is the entry point for the Wali Portal screen in the Flutter app.
    """,
)
async def get_dashboard(
    current_user: CurrentUser,
    db: DB,
):
    return await wali_svc.get_wali_dashboard(db, current_user.id)


@router.get(
    "/wards",
    summary="Wali: list all wards",
    description="All users this wali is actively guarding with their match summaries.",
)
async def get_wards(
    current_user: CurrentUser,
    db: DB,
):
    wards = await wali_svc.get_wali_wards(db, current_user.id)
    return {"total": len(wards), "wards": wards}


@router.get(
    "/decisions/pending",
    summary="Wali: all pending match decisions",
    description="""
Lists all matches across all wards that are waiting for this wali's
approve or decline decision.

Each entry includes the candidate's profile summary, compatibility score,
the interest message, and how many days the decision has been pending.
    """,
)
async def get_pending_decisions(
    current_user: CurrentUser,
    db: DB,
):
    decisions = await wali_svc.get_pending_decisions(db, current_user.id)
    return {
        "total_pending": len(decisions),
        "decisions":     decisions,
        "action":        "POST /api/v1/wali/matches/{match_id}/decide to approve or decline.",
    }


@router.get(
    "/matches/{match_id}",
    summary="Wali: full match summary",
    description="""
Complete match summary from the guardian's perspective.

Includes:
- Candidate's guardian-appropriate profile (no photos until mutual)
- Compatibility score and breakdown
- Your decision + other wali's decision status
- Message count, flagged message count
- Games completed
- Days since match became mutual
- Interest message written by the candidate

Use this before making an approve/decline decision.
    """,
)
async def get_match_summary(
    match_id: UUID,
    current_user: CurrentUser,
    db: DB,
):
    try:
        return await wali_svc.get_match_summary_for_wali(db, current_user.id, match_id)
    except ValueError as e:
        raise HTTPException(status_code=403, detail=str(e))


@router.post(
    "/matches/{match_id}/decide",
    summary="Wali: approve or decline a match",
    description="""
The guardian formally approves or declines a match for their ward.

**Approve:**
- Sets this wali's approval to True
- If the other wali has also approved → match status becomes **ACTIVE** 🌙
- If other wali hasn't decided yet → status becomes **APPROVED** (waiting)
- Both users and both walis are notified

**Decline:**
- Match is immediately **CLOSED**
- Both users are notified respectfully
- Reason is logged (shown to ward only)
- Cannot be undone

**Islamic note:** This models the Islamic principle that marriage requires
the guardian's consent. Both walis must approve for the match to proceed.
    """,
)
async def decide_match(
    match_id: UUID,
    body: WaliMatchDecisionRequest,
    current_user: CurrentUser,
    db: DB,
):
    try:
        result = await wali_svc.decide_match(
            db=db,
            wali_user_id=current_user.id,
            match_id=match_id,
            decision=body.decision,
            note=body.note,
        )
        await db.commit()
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))

    return result
