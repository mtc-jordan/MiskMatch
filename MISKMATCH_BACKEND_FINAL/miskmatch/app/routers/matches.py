"""
MiskMatch — Matches Router
The core product loop: discover → interest → wali → match → nikah.

Endpoints:
    GET  /matches/discover           → AI-ranked discovery feed
    POST /matches/interest           → Express interest in a profile
    GET  /matches                    → My matches (with status filter)
    GET  /matches/wali/pending       → Wali: pending approval decisions
    GET  /matches/{id}               → Single match detail
    POST /matches/{id}/respond       → Accept or decline an interest
    POST /matches/{id}/wali-approve  → Wali approves or declines
    POST /matches/{id}/close         → Close a match gracefully
    POST /matches/{id}/nikah         → Record a nikah outcome
    GET  /matches/{id}/compatibility → Detailed compatibility breakdown
"""

from datetime import datetime, timezone
from typing import Annotated, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.database import get_db
from app.models.models import (
    User, Profile, Match, MatchStatus,
    WaliRelationship, UserRole,
    MadhabChoice, PrayerFrequency,
)
from app.routers.auth import get_current_active_user
from app.schemas.matches import (
    ExpressInterestRequest, RespondToInterestRequest,
    WaliDecisionRequest, CloseMatchRequest,
    DiscoveryFeedResponse, DiscoveryProfileResponse,
    MatchResponse, MatchListResponse,
    InterestSentResponse, MatchActivatedResponse,
    MatchProfileSummary, WaliStatusSummary,
)
from app.services import matches as match_svc
from app.services.profiles import get_profile_by_user_id

router = APIRouter(prefix="/matches", tags=["Matches"])

CurrentUser = Annotated[User, Depends(get_current_active_user)]
DB          = Annotated[AsyncSession, Depends(get_db)]


# ─────────────────────────────────────────────
# DISCOVERY FEED
# ─────────────────────────────────────────────

@router.get(
    "/discover",
    response_model=DiscoveryFeedResponse,
    summary="Get AI-ranked discovery feed",
)
async def get_discovery_feed(
    current_user: CurrentUser,
    db: DB,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=5, le=50),
    min_age: Optional[int] = Query(None, ge=18, le=80),
    max_age: Optional[int] = Query(None, ge=18, le=80),
    country: Optional[str] = Query(None, max_length=2),
    madhab: Optional[MadhabChoice] = Query(None),
    prayer: Optional[PrayerFrequency] = Query(None),
):
    """
    Returns a ranked list of compatible profiles for the current user.

    Ranking factors:
    - Deen compatibility score (prayer, madhab, Quran level)
    - Life goals alignment (children, hijra, hajj)
    - Sifr personality compatibility
    - Trust score

    Privacy rules:
    - Photos are NEVER shown in discovery (blurred until mutual interest)
    - Last name shown as initial only
    - Voice intro always available

    Rate-limited: Barakah free users see 30 profiles/day.
    """
    # Must have a profile to discover
    my_profile = await get_profile_by_user_id(db, current_user.id)
    if not my_profile:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Complete your profile before discovering matches.",
        )

    # Get scored candidates
    scored_profiles, total = await match_svc.get_discovery_candidates(
        db=db,
        current_user=current_user,
        current_profile=my_profile,
        page=page,
        page_size=page_size,
        filter_min_age=min_age,
        filter_max_age=max_age,
        filter_country=country,
        filter_madhab=madhab,
        filter_prayer=prayer,
    )

    # Get set of user IDs I already expressed interest in
    from app.models.models import Match as MatchModel
    from sqlalchemy import or_
    existing_result = await db.execute(
        select(MatchModel.receiver_id).where(
            MatchModel.sender_id == current_user.id
        )
    )
    already_interested = {row[0] for row in existing_result.all()}

    # Build response cards
    cards = []
    for profile, score in scored_profiles:
        # Get age from date_of_birth
        age = None
        if profile.date_of_birth:
            dob = profile.date_of_birth.replace(
                tzinfo=profile.date_of_birth.tzinfo or timezone.utc
            )
            age = int((datetime.now(timezone.utc) - dob).days / 365.25)

        card = DiscoveryProfileResponse(
            user_id=profile.user_id,
            first_name=profile.first_name,
            last_name_initial=(profile.last_name[0].upper() + ".") if profile.last_name else "",
            age=age,
            city=profile.city,
            country=profile.country,
            photo_url=None,           # Always hidden in discovery
            voice_intro_url=profile.voice_intro_url,
            bio=profile.bio,
            madhab=profile.madhab,
            prayer_frequency=profile.prayer_frequency,
            hijab_stance=profile.hijab_stance,
            quran_level=profile.quran_level,
            occupation=profile.occupation,
            education_level=profile.education_level,
            wants_children=profile.wants_children,
            wants_hijra=profile.wants_hijra,
            is_revert=profile.is_revert,
            mosque_verified=profile.mosque_verified,
            scholar_endorsed=profile.scholar_endorsed,
            trust_score=profile.trust_score,
            deen_score=score,
            already_interested=profile.user_id in already_interested,
        )
        cards.append(card)

    return DiscoveryFeedResponse(
        profiles=cards,
        total=total,
        page=page,
        page_size=page_size,
        has_more=(page * page_size) < total,
    )


# ─────────────────────────────────────────────
# EXPRESS INTEREST
# ─────────────────────────────────────────────

@router.post(
    "/interest",
    response_model=InterestSentResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Express interest in a profile",
)
async def express_interest(
    body: ExpressInterestRequest,
    current_user: CurrentUser,
    db: DB,
):
    """
    Express romantic interest in another user.

    This is NOT a swipe. A minimum 20-character message is required,
    ensuring every expression of interest is intentional and respectful.

    The receiver and their wali are both notified.
    Free tier: 10 interests per month.
    Noor Premium / Misk Elite: unlimited.
    """
    # Ensure sender has a profile
    if not await get_profile_by_user_id(db, current_user.id):
        raise HTTPException(
            status_code=422,
            detail="Create your profile before expressing interest.",
        )

    # Create the match record
    try:
        match = await match_svc.express_interest(
            db=db,
            sender=current_user,
            receiver_id=body.receiver_id,
            message=body.message,
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(e),
        )

    # Notify receiver + wali (non-blocking background task in production)
    sender_profile = await get_profile_by_user_id(db, current_user.id)
    sender_name = sender_profile.first_name if sender_profile else "Someone"
    await match_svc.notify_interest_received(db, match, sender_name)

    # Check if receiver has a wali
    wali_result = await db.execute(
        select(WaliRelationship).where(
            WaliRelationship.user_id == body.receiver_id,
            WaliRelationship.is_active == True,
        )
    )
    wali_exists = wali_result.scalar_one_or_none() is not None

    await db.commit()

    return InterestSentResponse(
        match_id=match.id,
        status=match.status,
        message=(
            "Your interest has been sent respectfully. "
            "Their guardian has also been notified."
            if wali_exists else
            "Your interest has been sent. Awaiting their response."
        ),
        wali_notified=wali_exists,
    )


# ─────────────────────────────────────────────
# MY MATCHES LIST
# ─────────────────────────────────────────────

@router.get(
    "",
    response_model=MatchListResponse,
    summary="Get my matches",
)
async def get_my_matches(
    current_user: CurrentUser,
    db: DB,
    status_filter: Optional[MatchStatus] = Query(
        None,
        description="Filter by status: pending, mutual, approved, active, nikah, closed",
    ),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=5, le=50),
):
    """
    Returns all matches for the current user.
    Includes the other person's profile summary and wali status.
    """
    matches, total = await match_svc.get_my_matches(
        db=db,
        user_id=current_user.id,
        status_filter=status_filter,
        page=page,
        page_size=page_size,
    )

    # Batch-load profiles and users for all "other" sides to avoid N+1
    other_ids = set()
    for match in matches:
        other_ids.add(
            match.receiver_id if match.sender_id == current_user.id else match.sender_id
        )

    # Single query: all other profiles
    profiles_result = await db.execute(
        select(Profile).where(Profile.user_id.in_(other_ids))
    )
    profiles_map = {p.user_id: p for p in profiles_result.scalars().all()}

    # Single query: all other users (exclude soft-deleted)
    users_result = await db.execute(
        select(User).where(
            User.id.in_(other_ids),
            User.deleted_at.is_(None),
        )
    )
    users_map = {u.id: u for u in users_result.scalars().all()}

    # Load current user's profile once for compatibility fallback
    my_profile = await get_profile_by_user_id(db, current_user.id)

    # Build rich match responses
    match_responses = []
    for match in matches:
        other_id = (
            match.receiver_id
            if match.sender_id == current_user.id
            else match.sender_id
        )
        other_profile = profiles_map.get(other_id)
        other_user = users_map.get(other_id)

        # Build profile summary for the other person
        other_summary = None
        if other_profile and other_user:
            age = None
            if other_profile.date_of_birth:
                dob = other_profile.date_of_birth.replace(
                    tzinfo=other_profile.date_of_birth.tzinfo or timezone.utc
                )
                age = int((datetime.now(timezone.utc) - dob).days / 365.25)

            # Reveal photo only for active/approved matches
            show_photo = match.status in [
                MatchStatus.MUTUAL, MatchStatus.APPROVED,
                MatchStatus.ACTIVE, MatchStatus.NIKAH,
            ]

            compat = match_svc.compute_compatibility_score(
                my_profile, other_profile,
            ) if match.compatibility_score is None and my_profile else match.compatibility_score

            other_summary = MatchProfileSummary(
                user_id=other_profile.user_id,
                first_name=other_profile.first_name,
                last_name_initial=(
                    other_profile.last_name[0].upper() + "."
                    if other_profile.last_name else ""
                ),
                age=age,
                city=other_profile.city,
                country=other_profile.country,
                photo_url=other_profile.photo_url if show_photo else None,
                voice_intro_url=other_profile.voice_intro_url,
                madhab=other_profile.madhab,
                prayer_frequency=other_profile.prayer_frequency,
                mosque_verified=other_profile.mosque_verified,
                scholar_endorsed=other_profile.scholar_endorsed,
                trust_score=other_profile.trust_score,
                deen_score=compat,
            )

        match_responses.append(
            MatchResponse(
                id=match.id,
                status=match.status,
                created_at=match.created_at,
                updated_at=match.updated_at,
                other_profile=other_summary,
                sender_message=match.sender_message,
                receiver_response=match.receiver_response,
                wali_status=WaliStatusSummary(
                    sender_wali_approved=match.sender_wali_approved,
                    receiver_wali_approved=match.receiver_wali_approved,
                ),
                compatibility_score=match.compatibility_score,
                compatibility_breakdown=match.compatibility_breakdown,
                became_mutual_at=match.became_mutual_at,
                nikah_date=match.nikah_date,
            )
        )

    return MatchListResponse(
        matches=match_responses,
        total=total,
        page=page,
        has_more=(page * page_size) < total,
    )


# ─────────────────────────────────────────────
# WALI PENDING DECISIONS
# ─────────────────────────────────────────────

@router.get(
    "/wali/pending",
    summary="Wali: matches pending your approval",
)
async def get_wali_pending(
    current_user: CurrentUser,
    db: DB,
):
    """
    Returns all mutual matches where this guardian needs to make
    an approval decision. Used in the Wali Portal dashboard.
    """
    matches = await match_svc.get_wali_pending_matches(db, current_user.id)

    # Batch-load all needed profiles to avoid N+1
    all_user_ids = set()
    for match in matches:
        all_user_ids.add(match.sender_id)
        all_user_ids.add(match.receiver_id)

    profiles_result = await db.execute(
        select(Profile).where(Profile.user_id.in_(all_user_ids))
    )
    profiles_map = {p.user_id: p for p in profiles_result.scalars().all()}

    result = []
    for match in matches:
        sender_profile = profiles_map.get(match.sender_id)
        receiver_profile = profiles_map.get(match.receiver_id)

        result.append({
            "match_id":        str(match.id),
            "status":          match.status,
            "became_mutual_at": match.became_mutual_at,
            "sender": {
                "name": sender_profile.first_name if sender_profile else "Unknown",
                "city": sender_profile.city if sender_profile else None,
                "trust_score": sender_profile.trust_score if sender_profile else 0,
                "mosque_verified": sender_profile.mosque_verified if sender_profile else False,
            },
            "receiver": {
                "name": receiver_profile.first_name if receiver_profile else "Unknown",
                "city": receiver_profile.city if receiver_profile else None,
                "trust_score": receiver_profile.trust_score if receiver_profile else 0,
                "mosque_verified": receiver_profile.mosque_verified if receiver_profile else False,
            },
            "sender_message": match.sender_message,
            "your_decision_needed": True,
        })

    return {
        "pending_count": len(result),
        "matches": result,
    }


# ─────────────────────────────────────────────
# SINGLE MATCH DETAIL
# ─────────────────────────────────────────────

@router.get(
    "/{match_id}",
    response_model=MatchResponse,
    summary="Get single match detail",
)
async def get_match(
    match_id: UUID,
    current_user: CurrentUser,
    db: DB,
):
    """
    Returns full detail for a single match.
    User must be a participant (sender or receiver).
    """
    match = await match_svc.get_match_for_user(db, match_id, current_user.id)
    if not match:
        raise HTTPException(status_code=404, detail="Match not found.")

    other_id = (
        match.receiver_id
        if match.sender_id == current_user.id
        else match.sender_id
    )
    other_profile = await get_profile_by_user_id(db, other_id)

    show_photo = match.status in [
        MatchStatus.MUTUAL, MatchStatus.APPROVED,
        MatchStatus.ACTIVE, MatchStatus.NIKAH,
    ]

    other_summary = None
    if other_profile:
        age = None
        if other_profile.date_of_birth:
            dob = other_profile.date_of_birth.replace(
                tzinfo=other_profile.date_of_birth.tzinfo or timezone.utc
            )
            age = int((datetime.now(timezone.utc) - dob).days / 365.25)

        other_summary = MatchProfileSummary(
            user_id=other_profile.user_id,
            first_name=other_profile.first_name,
            last_name_initial=(
                other_profile.last_name[0].upper() + "."
                if other_profile.last_name else ""
            ),
            age=age,
            city=other_profile.city,
            country=other_profile.country,
            photo_url=other_profile.photo_url if show_photo else None,
            voice_intro_url=other_profile.voice_intro_url,
            madhab=other_profile.madhab,
            prayer_frequency=other_profile.prayer_frequency,
            mosque_verified=other_profile.mosque_verified,
            scholar_endorsed=other_profile.scholar_endorsed,
            trust_score=other_profile.trust_score,
            deen_score=match.compatibility_score,
        )

    return MatchResponse(
        id=match.id,
        status=match.status,
        created_at=match.created_at,
        updated_at=match.updated_at,
        other_profile=other_summary,
        sender_message=match.sender_message,
        receiver_response=match.receiver_response,
        wali_status=WaliStatusSummary(
            sender_wali_approved=match.sender_wali_approved,
            receiver_wali_approved=match.receiver_wali_approved,
        ),
        compatibility_score=match.compatibility_score,
        compatibility_breakdown=match.compatibility_breakdown,
        became_mutual_at=match.became_mutual_at,
        nikah_date=match.nikah_date,
    )


# ─────────────────────────────────────────────
# RESPOND TO INTEREST
# ─────────────────────────────────────────────

@router.post(
    "/{match_id}/respond",
    summary="Accept or decline an interest",
)
async def respond_to_interest(
    match_id: UUID,
    body: RespondToInterestRequest,
    current_user: CurrentUser,
    db: DB,
):
    """
    The receiver accepts or declines an expressed interest.

    On accept:
    - Status → MUTUAL
    - Both walis notified for approval decision
    - Both users notified of mutual interest

    On decline:
    - Status → CLOSED
    - Sender notified respectfully (no harsh rejection message)
    """
    match = await _get_match_or_404(db, match_id, current_user.id)

    if match.receiver_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the receiver can respond to an interest.",
        )

    try:
        updated = await match_svc.respond_to_interest(
            db=db,
            match=match,
            responder_id=current_user.id,
            accept=body.accept,
            message=body.message,
        )
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))

    if body.accept:
        await db.commit()
        return {
            "match_id": str(updated.id),
            "status": updated.status,
            "message": (
                "Masha'Allah! It's a mutual interest. "
                "Both families will now be notified for their blessing."
            ),
            "next_step": "Waiting for wali approval from both families.",
        }
    else:
        await db.commit()
        return {
            "match_id": str(updated.id),
            "status": updated.status,
            "message": "The interest has been respectfully declined.",
        }


# ─────────────────────────────────────────────
# WALI DECISION
# ─────────────────────────────────────────────

@router.post(
    "/{match_id}/wali-approve",
    summary="Wali approves or declines a mutual match",
)
async def wali_decision(
    match_id: UUID,
    body: WaliDecisionRequest,
    current_user: CurrentUser,
    db: DB,
):
    """
    A registered wali (guardian) approves or declines a mutual match.

    Both walis must approve before messaging and games activate.
    If either wali declines, the match is respectfully closed.

    Only registered, accepted walis can use this endpoint.
    """
    match = await match_svc.get_match_by_id(db, match_id)
    if not match:
        raise HTTPException(status_code=404, detail="Match not found.")

    try:
        updated = await match_svc.record_wali_decision(
            db=db,
            match=match,
            wali_user_id=current_user.id,
            approved=body.approved,
            note=body.note,
        )
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))

    if updated.status == MatchStatus.ACTIVE:
        # Both walis approved → notify both parties
        await match_svc.notify_match_activated(db, updated)
        await db.commit()
        return MatchActivatedResponse(
            match_id=updated.id,
            status=updated.status,
            message=(
                "Barakallahu lakuma! Both families have given their blessing. "
                "The journey begins."
            ),
            games_unlocked=match_svc.DAY_1_GAMES,
            first_prompt=match_svc.FIRST_CONVERSATION_PROMPT,
        )
    elif updated.status == MatchStatus.CLOSED:
        await db.commit()
        return {
            "match_id": str(updated.id),
            "status": updated.status,
            "message": "The match has been respectfully closed.",
        }
    else:
        await db.commit()
        return {
            "match_id": str(updated.id),
            "status": updated.status,
            "message": "Decision recorded. Waiting for the other family's decision.",
            "sender_wali_approved":   updated.sender_wali_approved,
            "receiver_wali_approved": updated.receiver_wali_approved,
        }


# ─────────────────────────────────────────────
# CLOSE MATCH
# ─────────────────────────────────────────────

@router.post(
    "/{match_id}/close",
    summary="Close a match gracefully",
)
async def close_match(
    match_id: UUID,
    body: CloseMatchRequest,
    current_user: CurrentUser,
    db: DB,
):
    """
    Close a match gracefully. Either participant can close.
    The other person is notified respectfully — no harsh message.
    """
    match = await _get_match_or_404(db, match_id, current_user.id)

    try:
        updated = await match_svc.close_match(
            db=db,
            match=match,
            user_id=current_user.id,
            reason=body.reason,
        )
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))

    await db.commit()
    return {
        "match_id": str(updated.id),
        "status": updated.status,
        "message": "Match closed with respect. May Allah bless your search.",
    }


# ─────────────────────────────────────────────
# RECORD NIKAH
# ─────────────────────────────────────────────

@router.post(
    "/{match_id}/nikah",
    summary="Record a nikah outcome",
)
async def record_nikah(
    match_id: UUID,
    current_user: CurrentUser,
    db: DB,
    nikah_date: datetime = Query(
        ...,
        description="The date of the nikah ceremony (ISO format)",
    ),
):
    """
    Mark a match as resulting in nikah.

    This is the ultimate success state — the reason MiskMatch exists.
    After recording: couple is invited to submit a Barakah Success Story.

    Alhamdulillah.
    """
    match = await _get_match_or_404(db, match_id, current_user.id)

    try:
        updated = await match_svc.record_nikah(
            db=db,
            match=match,
            user_id=current_user.id,
            nikah_date=nikah_date,
        )
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))

    await db.commit()

    return {
        "match_id":   str(updated.id),
        "status":     updated.status,
        "nikah_date": updated.nikah_date,
        "message":    "Barakallahu lakuma wa baraka 'alaykuma wa jama'a baynakuma fi khayr.",
        "arabic":     "بارك الله لكما وبارك عليكما وجمع بينكما في خير",
        "next_step":  "Share your story! Submit a Barakah Success Story to inspire others.",
    }


# ─────────────────────────────────────────────
# COMPATIBILITY BREAKDOWN
# ─────────────────────────────────────────────

@router.get(
    "/{match_id}/compatibility",
    summary="Get detailed compatibility breakdown",
)
async def get_compatibility(
    match_id: UUID,
    current_user: CurrentUser,
    db: DB,
):
    """
    Returns a detailed breakdown of the compatibility score
    between the current user and their match.

    Sections:
    - Deen alignment (prayer, madhab, Quran)
    - Life goals (children, hijra, hajj)
    - Personality (Sifr scores)
    - Practical (location, education, trust)
    """
    match = await _get_match_or_404(db, match_id, current_user.id)

    other_id = (
        match.receiver_id
        if match.sender_id == current_user.id
        else match.sender_id
    )

    my_profile    = await get_profile_by_user_id(db, current_user.id)
    other_profile = await get_profile_by_user_id(db, other_id)

    if not my_profile or not other_profile:
        raise HTTPException(status_code=422, detail="Both profiles must be complete.")

    # Detailed section scores
    def _match(a, b) -> bool:
        return a is not None and b is not None and a == b

    def _freq_score(a, b) -> int:
        freq_map = {"all_five": 5, "most": 4, "sometimes": 3,
                    "friday_only": 2, "working_on": 1}
        av = freq_map.get(str(a or ""), 0)
        bv = freq_map.get(str(b or ""), 0)
        if not av or not bv: return 0
        diff = abs(av - bv)
        return {0: 15, 1: 8, 2: 3}.get(diff, -8)

    breakdown = {
        "overall": match_svc.compute_compatibility_score(my_profile, other_profile),
        "sections": {
            "deen_alignment": {
                "score": 0,
                "max": 35,
                "details": {
                    "madhab_match":       _match(my_profile.madhab, other_profile.madhab),
                    "prayer_compatible":  _freq_score(my_profile.prayer_frequency, other_profile.prayer_frequency) >= 8,
                    "quran_compatible":   True,  # simplified
                    "finance_match":      _match(my_profile.islamic_finance_stance, other_profile.islamic_finance_stance),
                }
            },
            "life_goals": {
                "score": 0,
                "max": 30,
                "details": {
                    "children_aligned":   _match(my_profile.wants_children, other_profile.wants_children),
                    "hijra_aligned":      _match(my_profile.wants_hijra, other_profile.wants_hijra),
                    "hajj_aligned":       _match(my_profile.hajj_timeline, other_profile.hajj_timeline),
                }
            },
            "personality": {
                "score": 0,
                "max": 20,
                "details": {
                    "sifr_available":     bool(my_profile.sifr_scores and other_profile.sifr_scores),
                    "love_lang_match":    _match(my_profile.love_language, other_profile.love_language),
                }
            },
            "practical": {
                "score": 0,
                "max": 15,
                "details": {
                    "both_mosque_verified": my_profile.mosque_verified and other_profile.mosque_verified,
                    "trust_scores":       {
                        "yours": my_profile.trust_score,
                        "theirs": other_profile.trust_score,
                    },
                }
            },
        },
        "improvement_tips": _get_compat_tips(my_profile, other_profile),
    }

    return breakdown


# ─────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────

async def _get_match_or_404(
    db: AsyncSession,
    match_id: UUID,
    user_id: UUID,
) -> Match:
    match = await match_svc.get_match_for_user(db, match_id, user_id)
    if not match:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Match not found or you are not a participant.",
        )
    return match


def _get_compat_tips(profile_a: Profile, profile_b: Profile) -> list[str]:
    """Return actionable tips to improve match compatibility visibility."""
    tips = []
    if not profile_a.sifr_scores:
        tips.append("Complete the Sifr assessment to unlock personality compatibility")
    if not profile_a.mosque_verified:
        tips.append("Get mosque-verified to increase trust and boost your score")
    if not profile_a.voice_intro_url:
        tips.append("Add a voice introduction — it creates a much stronger first impression")
    if not profile_a.quran_level:
        tips.append("Add your Quran level to improve deen compatibility scoring")
    return tips[:3]  # max 3 tips
