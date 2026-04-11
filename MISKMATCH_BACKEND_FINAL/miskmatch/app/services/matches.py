"""
MiskMatch — Match Service
All business logic for the match lifecycle:
discovery → interest → wali approval → match → nikah
"""

import logging
from datetime import datetime, timezone
from typing import Optional
from uuid import UUID

from sqlalchemy import select, or_, and_, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.models import (
    User, UserStatus, Profile, Match, MatchStatus, Family,
    Notification, WaliRelationship, Gender,
)
from app.services.compatibility import compute_hybrid_score, rank_candidates

logger = logging.getLogger(__name__)

# ─────────────────────────────────────────────
# GAMES THAT UNLOCK ON MATCH ACTIVATION
# ─────────────────────────────────────────────

DAY_1_GAMES = [
    "qalb_quiz",
    "would_you_rather",
    "islamic_trivia",
]

FIRST_CONVERSATION_PROMPT = (
    "Assalamu Alaikum! You have a new match. "
    "Start with a warm greeting and share what drew you to their profile."
)


# ─────────────────────────────────────────────
# DISCOVERY
# ─────────────────────────────────────────────

async def get_discovery_candidates(
    db: AsyncSession,
    current_user: User,
    current_profile: Profile,
    page: int = 1,
    page_size: int = 20,
) -> tuple[list[tuple[Profile, float]], int]:
    """
    Return ranked candidate profiles for the discovery feed.

    Filtering:
    - Opposite gender only
    - Active users only
    - Not already sent/received interest
    - Not blocked by either party
    - Age within preferences
    - Country in preferred list (if set)

    Ranking:
    - Compatibility score (desc)
    - Trust score (desc)
    - Profile completeness

    Returns (list of (profile, score) tuples, total_count)
    """
    opposite_gender = (
        Gender.FEMALE if current_user.gender == Gender.MALE
        else Gender.MALE
    )

    # Users already in a match with current user (any status)
    existing_match_subq = (
        select(
            func.coalesce(Match.sender_id, Match.receiver_id)
        )
        .where(
            or_(
                Match.sender_id == current_user.id,
                Match.receiver_id == current_user.id,
            )
        )
    )

    # Base query: active users with profiles, opposite gender
    stmt = (
        select(Profile, User)
        .join(User, User.id == Profile.user_id)
        .where(
            and_(
                User.gender == opposite_gender,
                User.status == UserStatus.ACTIVE,
                User.id != current_user.id,
                Profile.user_id.not_in(
                    select(Match.sender_id).where(
                        or_(
                            Match.sender_id == current_user.id,
                            Match.receiver_id == current_user.id,
                        )
                    )
                ),
                Profile.user_id.not_in(
                    select(Match.receiver_id).where(
                        or_(
                            Match.sender_id == current_user.id,
                            Match.receiver_id == current_user.id,
                        )
                    )
                ),
            )
        )
    )

    # Age filter
    if current_profile.min_age and current_profile.max_age:
        from sqlalchemy import extract
        stmt = stmt.where(
            and_(
                func.date_part(
                    "year",
                    func.age(Profile.date_of_birth)
                ).between(
                    current_profile.min_age,
                    current_profile.max_age,
                )
            )
        )

    # Country preference filter
    if current_profile.preferred_countries:
        stmt = stmt.where(
            Profile.country.in_(current_profile.preferred_countries)
        )

    # Count total
    count_stmt = select(func.count()).select_from(stmt.subquery())
    total_result = await db.execute(count_stmt)
    total = total_result.scalar() or 0

    # Paginate
    offset = (page - 1) * page_size
    stmt = stmt.offset(offset).limit(page_size * 3)  # fetch 3x for scoring

    result = await db.execute(stmt)
    rows = result.all()

    # Score and rank candidates using the hybrid AI engine
    candidate_profiles = [profile for profile, user in rows]
    ranked = await rank_candidates(db, current_profile, candidate_profiles, limit=page_size)

    # Return ranked (profile, CompatibilityResult) pairs as (profile, score) for compat
    scored = [(profile, result.final_score) for profile, result in ranked]
    return scored, total


def compute_compatibility_score(
    profile_a: Profile,
    profile_b: Profile,
) -> float:
    """
    Multi-factor compatibility score (0-100).

    Weights:
    - Deen alignment: 35%
    - Life goals alignment: 30%
    - Personality/values: 20%
    - Practical factors: 15%

    Phase 4 will replace this with embedding cosine similarity.
    """
    score = 40.0  # generous baseline

    # ── Deen Alignment (35 pts max) ──────────

    # Madhab
    if profile_a.madhab and profile_b.madhab:
        if profile_a.madhab == profile_b.madhab:
            score += 12
        elif profile_a.madhab != "other" and profile_b.madhab != "other":
            score += 5

    # Prayer frequency (most impactful single factor)
    freq_map = {
        "all_five": 5, "most": 4, "sometimes": 3,
        "friday_only": 2, "working_on": 1,
    }
    a_freq = freq_map.get(str(profile_a.prayer_frequency or ""), 0)
    b_freq = freq_map.get(str(profile_b.prayer_frequency or ""), 0)
    if a_freq and b_freq:
        diff = abs(a_freq - b_freq)
        if diff == 0:   score += 15
        elif diff == 1: score += 8
        elif diff == 2: score += 3
        else:           score -= 8

    # Quran level compatibility
    quran_map = {
        "hafiz": 5, "memorising": 4, "strong": 3,
        "learning": 2, "beginner": 1,
    }
    a_quran = quran_map.get(str(profile_a.quran_level or "").lower(), 0)
    b_quran = quran_map.get(str(profile_b.quran_level or "").lower(), 0)
    if a_quran and b_quran:
        q_diff = abs(a_quran - b_quran)
        if q_diff <= 1: score += 8
        elif q_diff == 2: score += 3

    # ── Life Goals (30 pts max) ──────────────

    # Children — near-dealbreaker if mismatch
    if profile_a.wants_children is not None and profile_b.wants_children is not None:
        if profile_a.wants_children == profile_b.wants_children:
            score += 15
        else:
            score -= 12

    # Hijra intention
    if profile_a.wants_hijra is not None and profile_b.wants_hijra is not None:
        if profile_a.wants_hijra == profile_b.wants_hijra:
            score += 8
        else:
            score -= 5

    # Hajj timeline compatibility
    if profile_a.hajj_timeline and profile_b.hajj_timeline:
        if profile_a.hajj_timeline == profile_b.hajj_timeline:
            score += 7

    # ── Personality/Values (20 pts max) ──────

    # Sifr score compatibility
    if profile_a.sifr_scores and profile_b.sifr_scores:
        sifr_compat = _sifr_compatibility(
            profile_a.sifr_scores, profile_b.sifr_scores
        )
        score += sifr_compat * 0.20  # up to 20 pts

    # Islamic finance stance
    if profile_a.islamic_finance_stance and profile_b.islamic_finance_stance:
        if profile_a.islamic_finance_stance == profile_b.islamic_finance_stance:
            score += 5

    # ── Practical Factors (15 pts max) ───────

    # Trust score bonus (both highly verified = reliable match)
    trust_avg = ((profile_a.trust_score or 0) + (profile_b.trust_score or 0)) / 2
    score += (trust_avg / 100) * 10

    # Revert compatibility
    if profile_a.is_revert != profile_b.is_revert:
        score -= 3  # slight penalty, not a dealbreaker

    # Mosque-verified bonus
    if profile_a.mosque_verified and profile_b.mosque_verified:
        score += 5

    return round(max(0.0, min(100.0, score)), 1)


def _sifr_compatibility(scores_a: dict, scores_b: dict) -> float:
    """
    Compute compatibility between two Sifr assessment results.
    Returns 0-100 where 100 = perfect alignment.
    Complementary scores can be as good as matching scores.
    """
    if not scores_a or not scores_b:
        return 50.0

    dims = ["generosity", "patience", "honesty", "family", "community"]
    diffs = []

    for dim in dims:
        a = float(scores_a.get(dim, 50))
        b = float(scores_b.get(dim, 50))
        # Normalised absolute difference (0 = identical, 100 = max diff)
        diff = abs(a - b)
        diffs.append(diff)

    avg_diff = sum(diffs) / len(diffs) if diffs else 50
    # Convert: 0 diff = 100 compat, 100 diff = 0 compat
    return round(max(0.0, 100.0 - avg_diff), 1)


# ─────────────────────────────────────────────
# INTEREST
# ─────────────────────────────────────────────

async def express_interest(
    db: AsyncSession,
    sender: User,
    receiver_id: UUID,
    message: str,
) -> Match:
    """
    Create a pending match interest record.

    Rules:
    - Cannot express interest in yourself
    - Cannot express interest twice to same person
    - Cannot express interest in same gender
    - Free tier: max 10 interests/month
    """
    # Same user check
    if sender.id == receiver_id:
        raise ValueError("You cannot express interest in yourself.")

    # Check receiver exists and is active
    result = await db.execute(
        select(User).where(User.id == receiver_id)
    )
    receiver = result.scalar_one_or_none()
    if not receiver or receiver.status != "active":
        raise ValueError("User not found or unavailable.")

    # Gender check
    if sender.gender == receiver.gender:
        raise ValueError("Only opposite-gender matches are supported.")

    # Duplicate check (either direction)
    existing = await db.execute(
        select(Match).where(
            or_(
                and_(
                    Match.sender_id   == sender.id,
                    Match.receiver_id == receiver_id,
                ),
                and_(
                    Match.sender_id   == receiver_id,
                    Match.receiver_id == sender.id,
                ),
            )
        )
    )
    if existing.scalar_one_or_none():
        raise ValueError("You have already connected with this person.")

    # Monthly interest limit (free tier = 10)
    from app.models.models import SubscriptionTier
    if sender.subscription_tier == SubscriptionTier.BARAKAH:
        month_start = datetime.now(timezone.utc).replace(
            day=1, hour=0, minute=0, second=0, microsecond=0
        )
        count_result = await db.execute(
            select(func.count(Match.id)).where(
                and_(
                    Match.sender_id == sender.id,
                    Match.created_at >= month_start,
                )
            )
        )
        monthly_count = count_result.scalar() or 0
        if monthly_count >= 10:
            raise ValueError(
                "Monthly interest limit reached (10/month on Barakah plan). "
                "Upgrade to Noor Premium for unlimited interests."
            )

    # Create the match record
    match = Match(
        sender_id=sender.id,
        receiver_id=receiver_id,
        status=MatchStatus.PENDING,
        sender_message=message,
    )
    db.add(match)
    await db.flush()

    logger.info(
        f"Interest expressed: {sender.id} → {receiver_id} [match: {match.id}]"
    )
    return match


async def respond_to_interest(
    db: AsyncSession,
    match: Match,
    responder_id: UUID,
    accept: bool,
    message: Optional[str] = None,
) -> Match:
    """
    Receiver accepts or declines an interest.

    On accept:
    - Status → MUTUAL
    - Both walis notified for approval
    - became_mutual_at recorded

    On decline:
    - Status → CLOSED
    - Sender notified respectfully
    """
    if match.receiver_id != responder_id:
        raise ValueError("Only the receiver can respond to an interest.")

    if match.status != MatchStatus.PENDING:
        raise ValueError(
            f"Cannot respond to a match in '{match.status}' status."
        )

    match.receiver_response = message

    if accept:
        match.status = MatchStatus.MUTUAL
        match.became_mutual_at = datetime.now(timezone.utc)
        logger.info(f"Match {match.id} became MUTUAL")
    else:
        match.status = MatchStatus.CLOSED
        match.closed_reason = "receiver_declined"
        logger.info(f"Match {match.id} DECLINED by receiver")

    await db.flush()
    return match


# ─────────────────────────────────────────────
# WALI APPROVAL
# ─────────────────────────────────────────────

async def record_wali_decision(
    db: AsyncSession,
    match: Match,
    wali_user_id: UUID,
    approved: bool,
    note: Optional[str] = None,
) -> Match:
    """
    Record a wali's approval or rejection of a mutual match.

    The wali could be attached to either the sender or receiver.
    We detect which side by looking at wali relationships.

    Both walis must approve before status → APPROVED.
    If either wali declines → CLOSED.
    """
    # Determine which side this wali represents
    is_sender_wali = await _is_wali_of(db, wali_user_id, match.sender_id)
    is_receiver_wali = await _is_wali_of(db, wali_user_id, match.receiver_id)

    if not is_sender_wali and not is_receiver_wali:
        raise ValueError("You are not a guardian for either party in this match.")

    if match.status not in [MatchStatus.MUTUAL, MatchStatus.PENDING]:
        raise ValueError(f"Cannot make wali decision on match in '{match.status}' status.")

    now = datetime.now(timezone.utc)

    if not approved:
        # Wali vetoed — close match respectfully
        match.status = MatchStatus.CLOSED
        match.closed_reason = "wali_declined"
        logger.info(f"Match {match.id} closed by wali decision")
        await db.flush()
        return match

    # Record approval for the correct side
    if is_sender_wali:
        match.sender_wali_approved = True
        match.sender_wali_approved_at = now
    if is_receiver_wali:
        match.receiver_wali_approved = True
        match.receiver_wali_approved_at = now

    # Check if both walis have now approved → activate immediately
    if match.sender_wali_approved and match.receiver_wali_approved:
        match.status = MatchStatus.ACTIVE
        logger.info(f"Match {match.id} APPROVED by both walis → ACTIVE")

    await db.flush()
    return match


async def _is_wali_of(
    db: AsyncSession,
    wali_user_id: UUID,
    ward_user_id: UUID,
) -> bool:
    """Check if wali_user_id is a registered guardian of ward_user_id."""
    result = await db.execute(
        select(WaliRelationship).where(
            and_(
                WaliRelationship.user_id == ward_user_id,
                WaliRelationship.wali_user_id == wali_user_id,
                WaliRelationship.is_active == True,
                WaliRelationship.invitation_accepted == True,
            )
        )
    )
    return result.scalar_one_or_none() is not None


# ─────────────────────────────────────────────
# MATCH RETRIEVAL
# ─────────────────────────────────────────────

async def get_match_by_id(
    db: AsyncSession,
    match_id: UUID,
) -> Optional[Match]:
    result = await db.execute(
        select(Match).where(Match.id == match_id)
    )
    return result.scalar_one_or_none()


async def get_match_for_user(
    db: AsyncSession,
    match_id: UUID,
    user_id: UUID,
) -> Optional[Match]:
    """Get a match only if the user is a participant."""
    result = await db.execute(
        select(Match).where(
            and_(
                Match.id == match_id,
                or_(
                    Match.sender_id   == user_id,
                    Match.receiver_id == user_id,
                ),
            )
        )
    )
    return result.scalar_one_or_none()


async def get_my_matches(
    db: AsyncSession,
    user_id: UUID,
    status_filter: Optional[MatchStatus] = None,
    page: int = 1,
    page_size: int = 20,
) -> tuple[list[Match], int]:
    """Get all matches for a user with optional status filter."""
    stmt = select(Match).where(
        or_(
            Match.sender_id   == user_id,
            Match.receiver_id == user_id,
        )
    )

    if status_filter:
        stmt = stmt.where(Match.status == status_filter)

    # Count
    count_result = await db.execute(
        select(func.count()).select_from(stmt.subquery())
    )
    total = count_result.scalar() or 0

    # Order by most recent activity
    stmt = (
        stmt
        .order_by(Match.updated_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    )

    result = await db.execute(stmt)
    return result.scalars().all(), total


async def get_wali_pending_matches(
    db: AsyncSession,
    wali_user_id: UUID,
) -> list[Match]:
    """
    Get all MUTUAL matches where this wali needs to make a decision.
    Used in the Wali Portal dashboard.
    """
    # Find all users this person is wali for
    wards_result = await db.execute(
        select(WaliRelationship.user_id).where(
            and_(
                WaliRelationship.wali_user_id == wali_user_id,
                WaliRelationship.is_active == True,
                WaliRelationship.invitation_accepted == True,
            )
        )
    )
    ward_ids = [row[0] for row in wards_result.all()]

    if not ward_ids:
        return []

    result = await db.execute(
        select(Match).where(
            and_(
                Match.status == MatchStatus.MUTUAL,
                or_(
                    Match.sender_id.in_(ward_ids),
                    Match.receiver_id.in_(ward_ids),
                ),
            )
        ).order_by(Match.became_mutual_at.desc())
    )
    return result.scalars().all()


# ─────────────────────────────────────────────
# MATCH LIFECYCLE
# ─────────────────────────────────────────────

async def close_match(
    db: AsyncSession,
    match: Match,
    user_id: UUID,
    reason: str,
) -> Match:
    """Close a match gracefully. Either party can close."""
    if match.status in [MatchStatus.CLOSED, MatchStatus.BLOCKED]:
        raise ValueError("Match is already closed.")

    if user_id not in [match.sender_id, match.receiver_id]:
        raise ValueError("You are not a participant in this match.")

    match.status = MatchStatus.CLOSED
    match.closed_reason = reason
    await db.flush()

    logger.info(f"Match {match.id} closed by user {user_id}. Reason: {reason}")
    return match


async def record_nikah(
    db: AsyncSession,
    match: Match,
    user_id: UUID,
    nikah_date: datetime,
) -> Match:
    """
    Mark a match as resulting in nikah.
    This is the ultimate success state — the reason MiskMatch exists.
    """
    if match.status != MatchStatus.ACTIVE:
        raise ValueError("Match must be active to record a nikah.")

    if user_id not in [match.sender_id, match.receiver_id]:
        raise ValueError("You are not a participant in this match.")

    match.status = MatchStatus.NIKAH
    match.nikah_date = nikah_date

    await db.flush()

    logger.info(
        f"NIKAH recorded for match {match.id}! "
        f"Date: {nikah_date}. Alhamdulillah!"
    )
    return match


# ─────────────────────────────────────────────
# NOTIFICATIONS
# ─────────────────────────────────────────────

async def notify_interest_received(
    db: AsyncSession,
    match: Match,
    sender_name: str,
) -> None:
    """Create in-app notification for the receiver and their wali."""

    # Notify receiver
    notif = Notification(
        user_id=match.receiver_id,
        title="New interest received",
        title_ar="اهتمام جديد",
        body=f"{sender_name} has expressed interest in you.",
        body_ar=f"أبدى {sender_name} اهتمامه بك.",
        notification_type="interest_received",
        reference_id=match.id,
        reference_type="match",
    )
    db.add(notif)

    # Notify wali of receiver
    wali_result = await db.execute(
        select(WaliRelationship).where(
            and_(
                WaliRelationship.user_id == match.receiver_id,
                WaliRelationship.is_active == True,
                WaliRelationship.wali_user_id.isnot(None),
            )
        )
    )
    wali_rel = wali_result.scalar_one_or_none()
    if wali_rel and wali_rel.wali_user_id:
        wali_notif = Notification(
            user_id=wali_rel.wali_user_id,
            title="Interest received for your ward",
            title_ar="تم استلام طلب",
            body=f"{sender_name} has expressed interest in your ward.",
            body_ar=f"أبدى {sender_name} اهتمامه بمحميتك.",
            notification_type="wali_interest_received",
            reference_id=match.id,
            reference_type="match",
        )
        db.add(wali_notif)

    await db.flush()


async def notify_match_activated(
    db: AsyncSession,
    match: Match,
) -> None:
    """Notify both parties and their walis when match activates."""
    for user_id in [match.sender_id, match.receiver_id]:
        notif = Notification(
            user_id=user_id,
            title="It's a match! \U0001f339",
            title_ar="تمت المطابقة! \U0001f339",
            body="Your match has been approved. You may now begin your journey.",
            body_ar="تمت الموافقة على مطابقتك. يمكنك الآن بدء رحلتك.",
            notification_type="match_activated",
            reference_id=match.id,
            reference_type="match",
        )
        db.add(notif)

    await db.flush()
