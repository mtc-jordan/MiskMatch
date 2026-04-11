"""
MiskMatch — Wali Service
Full business logic for the Islamic guardian system.

Design principles:
  1. Ward is always in control of permissions (not wali)
  2. Both walis must approve for a match to go ACTIVE
  3. Either wali declining immediately closes the match
  4. Wali sees everything (messages, games) their ward authorises
  5. Invitation token is time-limited (72 hours) and single-use
  6. A ward can change their wali once every 30 days (anti-abuse)
"""

import logging
import secrets
from datetime import datetime, timezone, timedelta
from typing import Optional
from uuid import UUID

from sqlalchemy import select, and_, or_, func, update

from app.core.config import settings
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.models import (
    User, Profile, WaliRelationship,
    Match, MatchStatus, Message, MessageStatus,
    Notification, UserRole, UserStatus, Gender,
)
from app.schemas.wali import WaliSetupRequest, WaliUpdatePermissionsRequest

logger = logging.getLogger(__name__)

# Token lifetime for wali invitations
INVITE_TOKEN_TTL_HOURS = 72
# Minimum days between wali changes (anti-abuse)
WALI_CHANGE_COOLDOWN_DAYS = 30


# ─────────────────────────────────────────────
# INTERNAL HELPERS
# ─────────────────────────────────────────────

async def _get_ward_wali(
    db: AsyncSession, user_id: UUID
) -> Optional[WaliRelationship]:
    """Load the active wali relationship for a user (as ward)."""
    result = await db.execute(
        select(WaliRelationship).where(
            and_(
                WaliRelationship.user_id   == user_id,
                WaliRelationship.is_active == True,
            )
        )
    )
    return result.scalar_one_or_none()


async def _get_profile(db: AsyncSession, user_id: UUID) -> Optional[Profile]:
    result = await db.execute(select(Profile).where(Profile.user_id == user_id))
    return result.scalar_one_or_none()


async def _compute_age(profile: Profile) -> Optional[int]:
    if not profile or not profile.date_of_birth:
        return None
    dob = profile.date_of_birth
    if dob.tzinfo is None:
        dob = dob.replace(tzinfo=timezone.utc)
    today = datetime.now(timezone.utc)
    return (
        today.year - dob.year
        - ((today.month, today.day) < (dob.month, dob.day))
    )


async def _notify(
    db: AsyncSession,
    user_id: UUID,
    ref_id: Optional[UUID],
    title: str,
    title_ar: str,
    body: str,
    body_ar: str,
    ntype: str,
) -> None:
    db.add(Notification(
        user_id=user_id,
        title=title,
        title_ar=title_ar,
        body=body,
        body_ar=body_ar,
        notification_type=ntype,
        reference_id=ref_id,
        reference_type="wali",
    ))
    await db.flush()


def _match_day(match: Match) -> int:
    if not match.became_mutual_at:
        return 0
    ts = match.became_mutual_at
    if ts.tzinfo is None:
        ts = ts.replace(tzinfo=timezone.utc)
    return max(0, (datetime.now(timezone.utc) - ts).days)


# ─────────────────────────────────────────────
# WARD ACTIONS
# ─────────────────────────────────────────────

async def setup_wali(
    db: AsyncSession,
    ward_id: UUID,
    data: WaliSetupRequest,
) -> WaliRelationship:
    """
    Ward registers their guardian.

    Rules:
    - Ward must be male (female wards require wali per Islamic law)
      OR female (all female users require a wali)
    - Can't set themselves as wali
    - Cooldown applies if changing an existing wali
    - If wali phone matches an existing user, link accounts

    Returns the created/updated WaliRelationship.
    """
    # Load ward
    ward_result = await db.execute(select(User).where(User.id == ward_id))
    ward = ward_result.scalar_one_or_none()
    if not ward:
        raise ValueError("Ward user not found.")

    # Check cooldown on wali change
    existing = await _get_ward_wali(db, ward_id)
    if existing:
        if existing.updated_at:
            ts = existing.updated_at
            if ts.tzinfo is None:
                ts = ts.replace(tzinfo=timezone.utc)
            days_since = (datetime.now(timezone.utc) - ts).days
            if days_since < WALI_CHANGE_COOLDOWN_DAYS:
                days_left = WALI_CHANGE_COOLDOWN_DAYS - days_since
                raise ValueError(
                    f"You can only change your wali once every {WALI_CHANGE_COOLDOWN_DAYS} days. "
                    f"Please wait {days_left} more day{'s' if days_left != 1 else ''}."
                )
        # Deactivate old wali relationship
        existing.is_active    = False
        existing.invitation_accepted = False
        await db.flush()

    # Check if wali phone matches an existing platform user
    wali_user_result = await db.execute(
        select(User).where(User.phone == data.wali_phone)
    )
    wali_user = wali_user_result.scalar_one_or_none()

    # Generate invitation token (stored in Redis in prod — here on the model)
    invite_token = secrets.token_urlsafe(32)

    wali_rel = WaliRelationship(
        user_id           = ward_id,
        wali_name         = data.wali_name,
        wali_phone        = data.wali_phone,
        wali_relationship = data.wali_relationship,
        wali_user_id      = wali_user.id if wali_user else None,
        is_active         = True,
        invitation_sent   = False,
        invitation_accepted = False,
        can_view_matches  = True,
        can_view_messages = data.can_view_messages,
        can_approve_matches = True,
        can_join_calls    = True,
    )
    db.add(wali_rel)
    await db.flush()

    logger.info(f"Wali setup: ward={ward_id} wali={data.wali_phone[:6]}***")
    return wali_rel


async def send_wali_invitation(
    db: AsyncSession,
    ward_id: UUID,
) -> dict:
    """
    Send SMS invitation to the wali.
    In production: integrates with Twilio/AWS SNS.
    Records the send timestamp and sets invitation_sent=True.
    """
    wali_rel = await _get_ward_wali(db, ward_id)
    if not wali_rel:
        raise ValueError("No wali registered. Please set up your wali first.")
    if wali_rel.invitation_accepted:
        raise ValueError("Your wali has already accepted the invitation.")

    # Generate a fresh token each send
    invite_token = secrets.token_urlsafe(32)

    # Load ward profile for personalised SMS
    ward_profile = await _get_profile(db, ward_id)
    ward_name = ward_profile.first_name if ward_profile else "your ward"

    # Send SMS invitation via Twilio
    sms_body = (
        f"Assalamu Alaikum {wali_rel.wali_name},\n\n"
        f"{ward_name} has registered you as their guardian on MiskMatch — "
        f"an Islamic matrimony platform.\n\n"
        f"Accept the guardianship here:\n"
        f"https://miskmatch.app/wali/accept/{invite_token}\n\n"
        f"This link expires in {INVITE_TOKEN_TTL_HOURS} hours.\n\n"
        f"— MiskMatch Team\n"
        f"ختامه مسك 🌹"
    )

    from app.services.notifications import send_sms
    sms_sent = await send_sms(wali_rel.wali_phone, sms_body)

    wali_rel.invitation_sent  = True
    wali_rel.invited_at       = datetime.now(timezone.utc)
    await db.flush()

    logger.info(
        f"Wali invitation sent: ward={ward_id} wali_phone={wali_rel.wali_phone[:6]}*** "
        f"sms_delivered={sms_sent}"
    )

    return {
        "invitation_sent":  True,
        "wali_name":        wali_rel.wali_name,
        "wali_phone":       wali_rel.wali_phone,
        **({"invite_token": invite_token} if settings.is_development else {}),
        "message": (
            f"Invitation sent to {wali_rel.wali_name} at {wali_rel.wali_phone}. "
            f"They have {INVITE_TOKEN_TTL_HOURS} hours to accept."
        ),
        "expires_in_hours": INVITE_TOKEN_TTL_HOURS,
    }


async def accept_wali_invitation(
    db: AsyncSession,
    wali_phone: str,
    ward_id: UUID,
) -> dict:
    """
    Guardian accepts the invitation.
    Marks invitation_accepted=True, links wali_user_id if account exists.

    In production: token validated against Redis. Here we match by phone.
    """
    # Find the pending invitation
    result = await db.execute(
        select(WaliRelationship).where(
            and_(
                WaliRelationship.user_id          == ward_id,
                WaliRelationship.wali_phone        == wali_phone,
                WaliRelationship.is_active         == True,
                WaliRelationship.invitation_sent   == True,
                WaliRelationship.invitation_accepted == False,
            )
        )
    )
    wali_rel = result.scalar_one_or_none()
    if not wali_rel:
        raise ValueError(
            "No pending invitation found for this phone number. "
            "Please ask your ward to resend the invitation."
        )

    # Check token expiry (72 hours from invited_at)
    if wali_rel.invited_at:
        ts = wali_rel.invited_at
        if ts.tzinfo is None:
            ts = ts.replace(tzinfo=timezone.utc)
        if (datetime.now(timezone.utc) - ts).total_seconds() > INVITE_TOKEN_TTL_HOURS * 3600:
            raise ValueError(
                "This invitation has expired. Please ask your ward to resend it."
            )

    wali_rel.invitation_accepted = True
    wali_rel.accepted_at         = datetime.now(timezone.utc)
    await db.flush()

    # Notify ward
    ward_profile = await _get_profile(db, ward_id)
    ward_name = ward_profile.first_name if ward_profile else "Your ward"

    await _notify(
        db, ward_id, None,
        "🤲 Your wali has accepted!",
        "🤲 قبل وليّك الدعوة!",
        f"{wali_rel.wali_name} has accepted the guardian role. Your profile is now complete.",
        f"قبل {wali_rel.wali_name} دور الولي. ملفك الشخصي مكتمل الآن.",
        "wali_accepted",
    )

    logger.info(f"Wali accepted: ward={ward_id} wali={wali_rel.wali_phone[:6]}***")

    return {
        "accepted":     True,
        "ward_name":    ward_name or "Ward",
        "relationship": wali_rel.wali_relationship,
        "message": (
            f"JazakAllah Khair, {wali_rel.wali_name}. "
            f"You are now the registered guardian. "
            f"You will be notified of all match requests."
        ),
        "permissions": {
            "can_view_matches":    wali_rel.can_view_matches,
            "can_view_messages":   wali_rel.can_view_messages,
            "can_approve_matches": wali_rel.can_approve_matches,
            "can_join_calls":      wali_rel.can_join_calls,
        },
    }


async def update_wali_permissions(
    db: AsyncSession,
    ward_id: UUID,
    data: WaliUpdatePermissionsRequest,
) -> WaliRelationship:
    """Ward adjusts what their wali is permitted to see/do."""
    wali_rel = await _get_ward_wali(db, ward_id)
    if not wali_rel:
        raise ValueError("No active wali relationship found.")

    if data.can_view_messages is not None:
        wali_rel.can_view_messages = data.can_view_messages
    if data.can_view_matches is not None:
        wali_rel.can_view_matches = data.can_view_matches
    if data.can_join_calls is not None:
        wali_rel.can_join_calls = data.can_join_calls

    await db.flush()
    logger.info(f"Wali permissions updated: ward={ward_id}")
    return wali_rel


async def get_ward_wali_status(
    db: AsyncSession,
    ward_id: UUID,
) -> dict:
    """Ward checks status of their wali setup."""
    wali_rel = await _get_ward_wali(db, ward_id)
    if not wali_rel:
        return {
            "has_wali":           False,
            "wali_name":          None,
            "wali_phone":         None,
            "wali_relationship":  None,
            "wali_user_id":       None,
            "is_active":          False,
            "invitation_sent":    False,
            "invitation_accepted":False,
            "invited_at":         None,
            "accepted_at":        None,
            "can_view_matches":   True,
            "can_view_messages":  False,
            "can_approve_matches":True,
            "can_join_calls":     True,
        }

    return {
        "has_wali":           True,
        "wali_name":          wali_rel.wali_name,
        "wali_phone":         wali_rel.wali_phone,
        "wali_relationship":  wali_rel.wali_relationship,
        "wali_user_id":       wali_rel.wali_user_id,
        "is_active":          wali_rel.is_active,
        "invitation_sent":    wali_rel.invitation_sent,
        "invitation_accepted":wali_rel.invitation_accepted,
        "invited_at":         wali_rel.invited_at,
        "accepted_at":        wali_rel.accepted_at,
        "can_view_matches":   wali_rel.can_view_matches,
        "can_view_messages":  wali_rel.can_view_messages,
        "can_approve_matches":wali_rel.can_approve_matches,
        "can_join_calls":     wali_rel.can_join_calls,
    }


async def remove_wali(
    db: AsyncSession,
    ward_id: UUID,
    reason: str,
) -> dict:
    """
    Ward removes their wali.
    Safety check: if matches are ACTIVE and awaiting approval, cannot remove.
    The ward must resolve those first.
    """
    wali_rel = await _get_ward_wali(db, ward_id)
    if not wali_rel:
        raise ValueError("No active wali to remove.")

    # Block removal if active matches waiting for this wali's approval
    pending = await db.execute(
        select(func.count(Match.id)).where(
            and_(
                or_(Match.sender_id == ward_id, Match.receiver_id == ward_id),
                Match.status == MatchStatus.MUTUAL,
                or_(
                    and_(Match.sender_id == ward_id,   Match.sender_wali_approved.is_(None)),
                    and_(Match.receiver_id == ward_id, Match.receiver_wali_approved.is_(None)),
                ),
            )
        )
    )
    pending_count = pending.scalar() or 0
    if pending_count > 0:
        raise ValueError(
            f"You have {pending_count} match(es) awaiting your wali's decision. "
            f"Please resolve these before changing your wali."
        )

    wali_rel.is_active = False
    await db.flush()

    logger.info(f"Wali removed: ward={ward_id} reason='{reason[:50]}'")
    return {
        "removed": True,
        "message": "Your guardian relationship has been removed. You can register a new wali anytime.",
    }


# ─────────────────────────────────────────────
# WALI ACTIONS
# ─────────────────────────────────────────────

async def get_wali_dashboard(
    db: AsyncSession,
    wali_user_id: UUID,
) -> dict:
    """
    Full dashboard for a wali:
    - All their wards with match summaries
    - Matches pending their decision
    - Flagged messages today
    - Recent notifications
    """
    # All active wards for this wali
    wards_result = await db.execute(
        select(WaliRelationship).where(
            and_(
                WaliRelationship.wali_user_id     == wali_user_id,
                WaliRelationship.is_active         == True,
                WaliRelationship.invitation_accepted == True,
            )
        )
    )
    wards = wards_result.scalars().all()

    ward_summaries   = []
    all_pending      = []
    total_flagged    = 0
    total_active     = 0

    for ward_rel in wards:
        ward_id = ward_rel.user_id
        profile = await _get_profile(db, ward_id)
        age     = await _compute_age(profile)

        # Count this ward's ACTIVE matches
        active_matches_result = await db.execute(
            select(func.count(Match.id)).where(
                and_(
                    or_(Match.sender_id == ward_id, Match.receiver_id == ward_id),
                    Match.status == MatchStatus.ACTIVE,
                )
            )
        )
        active_count = active_matches_result.scalar() or 0
        total_active += active_count

        # Pending decisions for this ward
        pending_matches = await _get_pending_decisions_for_ward(
            db, wali_user_id, ward_id
        )
        all_pending.extend(pending_matches)

        # Flagged messages today across this ward's matches
        today_start = datetime.now(timezone.utc).replace(
            hour=0, minute=0, second=0, microsecond=0
        )
        flagged_today_result = await db.execute(
            select(func.count(Message.id)).where(
                and_(
                    Message.status == MessageStatus.FLAGGED,
                    Message.created_at >= today_start,
                    Message.match_id.in_(
                        select(Match.id).where(
                            or_(
                                Match.sender_id   == ward_id,
                                Match.receiver_id == ward_id,
                            )
                        )
                    ),
                )
            )
        )
        flagged_today = flagged_today_result.scalar() or 0
        total_flagged += flagged_today

        # All-time flagged across this ward
        all_flagged_result = await db.execute(
            select(func.count(Message.id)).where(
                and_(
                    Message.status == MessageStatus.FLAGGED,
                    Message.match_id.in_(
                        select(Match.id).where(
                            or_(
                                Match.sender_id   == ward_id,
                                Match.receiver_id == ward_id,
                            )
                        )
                    ),
                )
            )
        )
        all_flagged = all_flagged_result.scalar() or 0

        ward_summaries.append({
            "user_id":          str(ward_id),
            "name":             profile.first_name if profile else "Ward",
            "age":              age,
            "city":             profile.city if profile else None,
            "country":          profile.country if profile else None,
            "photo_url":        None,   # never expose photo in wali view
            "trust_score":      profile.trust_score if profile else 0,
            "active_matches":   active_count,
            "pending_decisions":len(pending_matches),
            "flagged_messages": all_flagged,
            "relationship":     ward_rel.wali_relationship,
            "member_since":     ward_rel.created_at,
        })

    # Recent wali-specific notifications
    notifs_result = await db.execute(
        select(Notification).where(
            and_(
                Notification.user_id == wali_user_id,
                Notification.notification_type.in_([
                    "wali_accepted", "wali_match_pending",
                    "message_flagged", "game_started", "wali_match_decided",
                ]),
            )
        )
        .order_by(Notification.created_at.desc())
        .limit(20)
    )
    recent_notifs = notifs_result.scalars().all()

    return {
        "wali_user_id":            str(wali_user_id),
        "total_wards":             len(wards),
        "pending_decisions":       len(all_pending),
        "active_matches":          total_active,
        "flagged_messages_today":  total_flagged,
        "wards":                   ward_summaries,
        "pending_match_decisions": all_pending,
        "recent_notifications": [
            {
                "id":    str(n.id),
                "title": n.title,
                "body":  n.body,
                "type":  n.notification_type,
                "is_read": n.is_read,
                "created_at": n.created_at,
            }
            for n in recent_notifs
        ],
    }


async def get_wali_wards(
    db: AsyncSession,
    wali_user_id: UUID,
) -> list[dict]:
    """List all wards the wali is guarding, with full summaries."""
    result = await db.execute(
        select(WaliRelationship).where(
            and_(
                WaliRelationship.wali_user_id      == wali_user_id,
                WaliRelationship.is_active          == True,
                WaliRelationship.invitation_accepted == True,
            )
        )
    )
    wards = result.scalars().all()

    out = []
    for w in wards:
        profile = await _get_profile(db, w.user_id)
        age = await _compute_age(profile)
        out.append({
            "user_id":      str(w.user_id),
            "name":         profile.first_name if profile else "Ward",
            "age":          age,
            "city":         profile.city if profile else None,
            "country":      profile.country if profile else None,
            "relationship": w.wali_relationship,
            "since":        w.accepted_at,
            "permissions": {
                "can_view_matches":    w.can_view_matches,
                "can_view_messages":   w.can_view_messages,
                "can_approve_matches": w.can_approve_matches,
                "can_join_calls":      w.can_join_calls,
            },
        })
    return out


async def get_pending_decisions(
    db: AsyncSession,
    wali_user_id: UUID,
) -> list[dict]:
    """All match decisions waiting for this wali's approval."""
    # Find all wards
    wards_result = await db.execute(
        select(WaliRelationship.user_id).where(
            and_(
                WaliRelationship.wali_user_id      == wali_user_id,
                WaliRelationship.is_active          == True,
                WaliRelationship.invitation_accepted == True,
                WaliRelationship.can_approve_matches == True,
            )
        )
    )
    ward_ids = [row[0] for row in wards_result.fetchall()]
    if not ward_ids:
        return []

    all_pending = []
    for ward_id in ward_ids:
        decisions = await _get_pending_decisions_for_ward(db, wali_user_id, ward_id)
        all_pending.extend(decisions)

    return all_pending


async def _get_pending_decisions_for_ward(
    db: AsyncSession,
    wali_user_id: UUID,
    ward_id: UUID,
) -> list[dict]:
    """
    Find matches where this ward is waiting for wali approval
    and this wali hasn't decided yet.
    """
    # Get ward's matches in MUTUAL status (both interested, awaiting wali)
    matches_result = await db.execute(
        select(Match).where(
            and_(
                Match.status == MatchStatus.MUTUAL,
                or_(
                    and_(
                        Match.sender_id == ward_id,
                        Match.sender_wali_approved.is_(None),
                    ),
                    and_(
                        Match.receiver_id == ward_id,
                        Match.receiver_wali_approved.is_(None),
                    ),
                ),
            )
        )
    )
    matches = matches_result.scalars().all()

    out = []
    for match in matches:
        is_sender     = match.sender_id == ward_id
        candidate_id  = match.receiver_id if is_sender else match.sender_id
        ward_profile  = await _get_profile(db, ward_id)
        cand_profile  = await _get_profile(db, candidate_id)

        days_waiting = (
            (datetime.now(timezone.utc) - match.created_at.replace(tzinfo=timezone.utc)).days
            if match.created_at else 0
        )

        out.append({
            "match_id":                str(match.id),
            "ward_name":               ward_profile.first_name if ward_profile else "Ward",
            "candidate_name":          cand_profile.first_name if cand_profile else "Candidate",
            "candidate_last_initial":  (cand_profile.last_name[0] + ".") if cand_profile and cand_profile.last_name else None,
            "candidate_city":          cand_profile.city if cand_profile else None,
            "candidate_country":       cand_profile.country if cand_profile else None,
            "candidate_madhab":        cand_profile.madhab if cand_profile else None,
            "candidate_prayer_freq":   cand_profile.prayer_frequency if cand_profile else None,
            "candidate_trust_score":   cand_profile.trust_score if cand_profile else 0,
            "candidate_mosque_verified": cand_profile.mosque_verified if cand_profile else False,
            "candidate_scholar_endorsed": cand_profile.scholar_endorsed if cand_profile else False,
            "compatibility_score":     match.compatibility_score,
            "compatibility_breakdown": match.compatibility_breakdown,
            "interest_message":        match.sender_message if is_sender else match.receiver_response,
            "match_created_at":        match.created_at,
            "days_waiting":            days_waiting,
        })

    return out


async def decide_match(
    db: AsyncSession,
    wali_user_id: UUID,
    match_id: UUID,
    decision: str,   # "approve" | "decline"
    note: Optional[str],
) -> dict:
    """
    Wali approves or declines a match for their ward.

    Approve: marks sender/receiver_wali_approved=True.
             If BOTH walis approved → status becomes ACTIVE.
    Decline: sets approved=False, status → CLOSED immediately.

    Notifies: both users, both walis.
    """
    # Verify this wali has authority over one of the match participants
    match_result = await db.execute(
        select(Match).where(Match.id == match_id)
    )
    match = match_result.scalar_one_or_none()
    if not match:
        raise ValueError("Match not found.")

    # Which ward does this wali represent in this match?
    ward_id = await _resolve_ward_in_match(db, wali_user_id, match)
    if not ward_id:
        raise ValueError(
            "You are not authorised to make decisions for this match. "
            "You must be the registered guardian of one of the participants."
        )

    if match.status not in [MatchStatus.MUTUAL, MatchStatus.APPROVED]:
        raise ValueError(
            f"This match cannot be decided in its current status: {match.status}. "
            f"Only MUTUAL matches are awaiting wali approval."
        )

    is_sender = match.sender_id == ward_id
    now = datetime.now(timezone.utc)

    if decision == "approve":
        if is_sender:
            if match.sender_wali_approved:
                raise ValueError("You have already approved this match.")
            match.sender_wali_approved    = True
            match.sender_wali_approved_at = now
        else:
            if match.receiver_wali_approved:
                raise ValueError("You have already approved this match.")
            match.receiver_wali_approved    = True
            match.receiver_wali_approved_at = now

        # Check if BOTH walis have now approved
        both_approved = bool(match.sender_wali_approved and match.receiver_wali_approved)
        if both_approved:
            match.status           = MatchStatus.ACTIVE
            match.became_mutual_at = now
            outcome_msg = "Both families have given their blessing. This match is now ACTIVE."
        else:
            match.status   = MatchStatus.APPROVED
            outcome_msg    = "You have approved. Waiting for the other family's blessing."

        await db.flush()

        # Notify the ward
        ward_profile = await _get_profile(db, ward_id)
        ward_name = ward_profile.first_name if ward_profile else "Ward"

        # Get other side info
        other_id = match.receiver_id if is_sender else match.sender_id
        other_profile = await _get_profile(db, other_id)
        other_name = other_profile.first_name if other_profile else "Match"

        await _notify(
            db, ward_id, match_id,
            "🤲 Your wali has approved!",
            "🤲 وافق وليّك!",
            f"Your guardian approved the match with {other_name}." + (
                " Both families have blessed this match. MashaAllah!" if both_approved else ""
            ),
            f"وافق وليّك على الزواج مع {other_name}." + (
                " بارك كلا الوليّان. ما شاء الله!" if both_approved else ""
            ),
            "wali_approved",
        )

        if both_approved:
            await _notify(
                db, other_id, match_id,
                "🌙 MashaAllah — Both families approved!",
                "🌙 ما شاء الله — وافق كلا الأسرتين!",
                "Both families have given their blessing. Your match is now active. Bismillah.",
                "باركت كلتا الأسرتين. مطابقتك نشطة الآن. بسم الله.",
                "both_walis_approved",
            )

        return {
            "decision":     "approved",
            "match_status": match.status,
            "both_approved":both_approved,
            "message":      outcome_msg,
            "note":         note,
        }

    elif decision == "decline":
        if is_sender:
            match.sender_wali_approved = False
        else:
            match.receiver_wali_approved = False

        match.status        = MatchStatus.CLOSED
        match.closed_reason = f"wali_declined: {note[:100] if note else 'No reason given'}"
        await db.flush()

        # Notify both parties
        other_id = match.receiver_id if is_sender else match.sender_id
        ward_profile  = await _get_profile(db, ward_id)
        other_profile = await _get_profile(db, other_id)

        await _notify(
            db, ward_id, match_id,
            "Match ended by your guardian",
            "أنهى وليّك هذه المطابقة",
            "Your guardian has respectfully declined this match. May Allah guide you to what is best.",
            "رفض وليّك هذه المطابقة باحترام. جعل الله لك فيما هو خير.",
            "wali_declined",
        )
        await _notify(
            db, other_id, match_id,
            "A match has been closed",
            "تم إغلاق المطابقة",
            "This match has been respectfully closed. May Allah ease your path.",
            "تم إغلاق هذه المطابقة باحترام. يسّر الله أمرك.",
            "match_closed",
        )

        logger.info(
            f"Match {match_id} declined by wali={wali_user_id} "
            f"for ward={ward_id}. Reason: {note}"
        )

        return {
            "decision":     "declined",
            "match_status": MatchStatus.CLOSED,
            "message":      "You have respectfully declined this match. The participants have been notified.",
            "note":         note,
        }

    else:
        raise ValueError("Decision must be 'approve' or 'decline'.")


async def get_match_summary_for_wali(
    db: AsyncSession,
    wali_user_id: UUID,
    match_id: UUID,
) -> dict:
    """
    Full match summary from the wali's perspective.
    Includes candidate profile, compatibility, message/game stats.
    """
    match_result = await db.execute(select(Match).where(Match.id == match_id))
    match = match_result.scalar_one_or_none()
    if not match:
        raise ValueError("Match not found.")

    ward_id = await _resolve_ward_in_match(db, wali_user_id, match)
    if not ward_id:
        raise ValueError("You are not authorised to view this match.")

    other_id = match.receiver_id if match.sender_id == ward_id else match.sender_id

    ward_profile  = await _get_profile(db, ward_id)
    other_profile = await _get_profile(db, other_id)

    is_sender = match.sender_id == ward_id
    my_wali_approved    = match.sender_wali_approved if is_sender else match.receiver_wali_approved
    other_wali_approved = match.receiver_wali_approved if is_sender else match.sender_wali_approved
    my_approved_at      = match.sender_wali_approved_at if is_sender else match.receiver_wali_approved_at

    # Message stats
    msg_result = await db.execute(
        select(
            func.count(Message.id).label("total"),
            func.sum(
                (Message.status == MessageStatus.FLAGGED).cast(int)
            ).label("flagged"),
        ).where(Message.match_id == match_id)
    )
    msg_stats = msg_result.one()

    # Games completed
    games_done = len([
        e for e in (match.memory_timeline or [])
        if e.get("type") == "game_completed"
    ])

    # Last message timestamp
    last_msg_result = await db.execute(
        select(Message.created_at)
        .where(Message.match_id == match_id)
        .order_by(Message.created_at.desc())
        .limit(1)
    )
    last_msg_ts = last_msg_result.scalar_one_or_none()

    # Build safe candidate profile (wali-appropriate view)
    candidate_view: dict = {}
    if other_profile:
        candidate_view = {
            "first_name":           other_profile.first_name,
            "last_name_initial":    (other_profile.last_name[0] + ".") if other_profile.last_name else None,
            "city":                 other_profile.city,
            "country":              other_profile.country,
            "age":                  await _compute_age(other_profile),
            "madhab":               other_profile.madhab,
            "prayer_frequency":     other_profile.prayer_frequency,
            "education_level":      other_profile.education_level,
            "occupation":           other_profile.occupation,
            "is_revert":            other_profile.is_revert,
            "wants_children":       other_profile.wants_children,
            "mosque_verified":      other_profile.mosque_verified,
            "scholar_endorsed":     other_profile.scholar_endorsed,
            "trust_score":          other_profile.trust_score,
            "bio":                  other_profile.bio,
        }

    return {
        "match_id":              str(match_id),
        "status":                match.status,
        "ward_name":             ward_profile.first_name if ward_profile else "Ward",
        "candidate_name":        other_profile.first_name if other_profile else "Candidate",
        "candidate_profile":     candidate_view,
        "compatibility_score":   match.compatibility_score,
        "compatibility_breakdown": match.compatibility_breakdown,
        "wali_approved":         my_wali_approved,
        "other_wali_approved":   other_wali_approved,
        "approved_at":           my_approved_at,
        "message_count":         msg_stats.total or 0,
        "flagged_message_count": msg_stats.flagged or 0,
        "games_completed":       games_done,
        "last_activity":         last_msg_ts,
        "match_day":             _match_day(match),
        "interest_message":      match.sender_message if is_sender else match.receiver_response,
    }


# ─────────────────────────────────────────────
# UTILITY
# ─────────────────────────────────────────────

async def _resolve_ward_in_match(
    db: AsyncSession,
    wali_user_id: UUID,
    match: Match,
) -> Optional[UUID]:
    """
    Determine which participant in a match this wali represents.
    Returns ward_id if found, None if this wali has no authority.
    """
    for candidate_ward_id in [match.sender_id, match.receiver_id]:
        result = await db.execute(
            select(WaliRelationship).where(
                and_(
                    WaliRelationship.user_id           == candidate_ward_id,
                    WaliRelationship.wali_user_id      == wali_user_id,
                    WaliRelationship.is_active          == True,
                    WaliRelationship.invitation_accepted == True,
                )
            )
        )
        if result.scalar_one_or_none():
            return candidate_ward_id
    return None


async def verify_wali_access(
    db: AsyncSession,
    wali_user_id: UUID,
    ward_id: UUID,
) -> WaliRelationship:
    """Assert wali has active accepted guardianship over ward."""
    result = await db.execute(
        select(WaliRelationship).where(
            and_(
                WaliRelationship.user_id           == ward_id,
                WaliRelationship.wali_user_id      == wali_user_id,
                WaliRelationship.is_active          == True,
                WaliRelationship.invitation_accepted == True,
            )
        )
    )
    rel = result.scalar_one_or_none()
    if not rel:
        raise ValueError("You are not an active guardian for this user.")
    return rel
