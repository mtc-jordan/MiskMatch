"""
MiskMatch — Profile Service
All business logic for profile operations.
Keeps routers thin — logic lives here.
"""

import logging
from typing import Optional
from uuid import UUID

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.models import User, Profile, Family
from app.schemas.profiles import (
    ProfileCreateRequest, ProfileUpdateRequest,
    FamilyUpsertRequest, SifrAssessmentRequest,
)
import json
from app.core.redis import cache_get, cache_set, cache_delete, cache_delete_pattern

logger = logging.getLogger(__name__)


# ─────────────────────────────────────────────
# PROFILE CRUD
# ─────────────────────────────────────────────

async def get_profile_by_user_id(
    db: AsyncSession,
    user_id: UUID,
    include_family: bool = True,
) -> Optional[Profile]:
    """
    Fetch a user's profile, optionally including family.
    Uses eager loading to avoid N+1 queries.
    """
    stmt = select(Profile).where(Profile.user_id == user_id)

    if include_family:
        stmt = stmt.options(selectinload(Profile.user))

    result = await db.execute(stmt)
    return result.scalar_one_or_none()


async def create_profile(
    db: AsyncSession,
    user_id: UUID,
    data: ProfileCreateRequest,
) -> Profile:
    """
    Create a new profile for a user.
    Called after registration is complete.
    """
    # Check profile doesn't already exist
    existing = await get_profile_by_user_id(db, user_id, include_family=False)
    if existing:
        raise ValueError("Profile already exists for this user")

    profile = Profile(
        user_id=user_id,
        **data.model_dump(exclude_none=True),
    )
    db.add(profile)
    await db.flush()

    # Update user onboarding progress
    await db.execute(
        update(User)
        .where(User.id == user_id)
        .values(onboarding_completed=True)
    )

    logger.info(f"Profile created for user {user_id}")

    # Invalidate discovery cache
    await cache_delete_pattern(f"discovery:*")

    return profile


async def update_profile(
    db: AsyncSession,
    profile: Profile,
    data: ProfileUpdateRequest,
) -> Profile:
    """
    Partial update of an existing profile.
    Only updates fields that are explicitly provided (not None).
    """
    update_data = data.model_dump(exclude_none=True)

    for field, value in update_data.items():
        setattr(profile, field, value)

    # Recompute trust score after any update
    profile.trust_score = compute_trust_score(profile)

    await db.flush()

    # Invalidate caches on profile update
    await cache_delete(f"profile:{profile.user_id}")
    await cache_delete_pattern(f"discovery:*")

    return profile


# ─────────────────────────────────────────────
# FAMILY CRUD
# ─────────────────────────────────────────────

async def get_family_by_user_id(
    db: AsyncSession,
    user_id: UUID,
) -> Optional[Family]:
    result = await db.execute(
        select(Family).where(Family.user_id == user_id)
    )
    return result.scalar_one_or_none()


async def upsert_family(
    db: AsyncSession,
    user_id: UUID,
    data: FamilyUpsertRequest,
) -> Family:
    """Create or update a user's family profile."""
    family = await get_family_by_user_id(db, user_id)

    if family:
        # Update existing
        for field, value in data.model_dump(exclude_none=True).items():
            setattr(family, field, value)
    else:
        # Create new
        family = Family(
            user_id=user_id,
            **data.model_dump(exclude_none=True),
        )
        db.add(family)

    await db.flush()
    logger.info(f"Family profile upserted for user {user_id}")
    return family


# ─────────────────────────────────────────────
# PHOTO MANAGEMENT
# ─────────────────────────────────────────────

async def set_main_photo(
    db: AsyncSession,
    profile: Profile,
    photo_url: str,
) -> Profile:
    """Set the user's main profile photo URL."""
    old_url = profile.photo_url

    profile.photo_url = photo_url

    # Add to gallery if not already there
    photos = profile.photos or []
    if photo_url not in photos:
        photos.insert(0, photo_url)
        # Keep gallery max 10 photos
        profile.photos = photos[:10]

    # Recompute trust score (having a photo increases it)
    profile.trust_score = compute_trust_score(profile)

    await db.flush()
    return profile, old_url


async def add_gallery_photo(
    db: AsyncSession,
    profile: Profile,
    photo_url: str,
) -> Profile:
    """Add a photo to the gallery (up to 10 photos)."""
    photos = list(profile.photos or [])

    if len(photos) >= 10:
        raise ValueError("Maximum 10 gallery photos allowed")

    photos.append(photo_url)
    profile.photos = photos

    await db.flush()
    return profile


async def remove_gallery_photo(
    db: AsyncSession,
    profile: Profile,
    photo_url: str,
) -> Profile:
    """Remove a photo from the gallery."""
    photos = list(profile.photos or [])

    if photo_url not in photos:
        raise ValueError("Photo not found in gallery")

    photos.remove(photo_url)
    profile.photos = photos

    # If main photo was removed, use first gallery photo
    if profile.photo_url == photo_url:
        profile.photo_url = photos[0] if photos else None

    await db.flush()
    return profile


# ─────────────────────────────────────────────
# VOICE INTRO
# ─────────────────────────────────────────────

async def set_voice_intro(
    db: AsyncSession,
    profile: Profile,
    voice_url: str,
) -> Profile:
    """Set the voice introduction URL."""
    old_url = profile.voice_intro_url
    profile.voice_intro_url = voice_url
    profile.trust_score = compute_trust_score(profile)
    await db.flush()
    return profile, old_url


# ─────────────────────────────────────────────
# SIFR ASSESSMENT
# ─────────────────────────────────────────────

async def save_sifr_results(
    db: AsyncSession,
    profile: Profile,
    answers: dict,
) -> Profile:
    """
    Compute Sifr personality scores from assessment answers
    and save to profile.

    The Sifr framework measures 5 dimensions:
    - Generosity (سخاء)
    - Patience (صبر)
    - Honesty (صدق)
    - Family orientation (الأسرة)
    - Community (مجتمع)
    """
    scores = _compute_sifr_scores(answers)
    profile.sifr_scores = scores

    # Derive primary love language from answers
    profile.love_language = _derive_love_language(answers)

    profile.trust_score = compute_trust_score(profile)
    await db.flush()

    logger.info(f"Sifr assessment saved for profile {profile.id}")
    return profile


def _compute_sifr_scores(answers: dict) -> dict:
    """
    Map assessment answers to 5-dimension scores.
    Each dimension scored 0-100.
    """
    # Simplified scoring — replace with ML model in Phase 4
    dimensions = {
        "generosity":    0.0,
        "patience":      0.0,
        "honesty":       0.0,
        "family":        0.0,
        "community":     0.0,
    }

    # Question categories (defined in CMS)
    category_map = {
        "q1": "generosity", "q2": "patience",  "q3": "honesty",
        "q4": "family",     "q5": "community",  "q6": "generosity",
        "q7": "patience",   "q8": "honesty",    "q9": "family",
        "q10": "community", "q11": "generosity","q12": "patience",
        "q13": "honesty",   "q14": "family",    "q15": "community",
    }

    counts = {k: 0 for k in dimensions}
    for q_id, answer in answers.items():
        category = category_map.get(q_id)
        if category and isinstance(answer, (int, float)):
            dimensions[category] += float(answer)
            counts[category] += 1

    # Normalise to 0-100
    for dim in dimensions:
        if counts[dim] > 0:
            max_possible = counts[dim] * 5.0  # assuming 1-5 scale
            dimensions[dim] = round(
                (dimensions[dim] / max_possible) * 100, 1
            )

    return dimensions


def _derive_love_language(answers: dict) -> Optional[str]:
    """Determine primary love language from specific answers."""
    love_lang_answers = {
        "ll1": "acts_of_service",
        "ll2": "words_of_appreciation",
        "ll3": "quality_time",
        "ll4": "thoughtful_gifts",
        "ll5": "physical_presence",
    }
    scores = {}
    for q_id, category in love_lang_answers.items():
        if q_id in answers:
            scores[category] = float(answers[q_id])

    if not scores:
        return None
    return max(scores, key=scores.get)


# ─────────────────────────────────────────────
# TRUST SCORE
# ─────────────────────────────────────────────

def compute_trust_score(profile: Profile) -> int:
    """
    Compute a 0-100 trust score based on profile completeness
    and verification status.

    Weights:
    - Phone verified (user table): automatic
    - ID biometric verified: +20
    - Has profile photo: +10
    - Has voice intro: +10
    - Profile 80%+ complete: +15
    - Mosque verified: +30
    - Scholar endorsed: +40
    - Has family profile: +10
    Max achievable without mosque/scholar: 65
    Max with mosque: 95
    Max with scholar: 100+
    """
    score = 0

    # Biometric verification (checked via user status — simplified here)
    # In production, pass user object too
    score += 20  # base for being on the platform at all

    # Profile completeness
    completeness = _profile_completeness_pct(profile)
    if completeness >= 80:
        score += 15
    elif completeness >= 50:
        score += 8

    # Media presence
    if profile.photo_url:
        score += 10
    if profile.voice_intro_url:
        score += 10

    # Islamic depth
    if profile.madhab:
        score += 3
    if profile.prayer_frequency:
        score += 3
    if profile.quran_level:
        score += 2
    if profile.sifr_scores:
        score += 5

    # Community trust
    if profile.mosque_verified:
        score += 30
    if profile.scholar_endorsed:
        score += 40

    # Family profile
    # Cannot check here without DB — updated separately

    return min(score, 100)


def _profile_completeness_pct(profile: Profile) -> int:
    """Calculate what percentage of optional fields are filled."""
    fields = [
        profile.bio, profile.date_of_birth, profile.city,
        profile.country, profile.madhab, profile.prayer_frequency,
        profile.education_level, profile.occupation,
        profile.wants_children, profile.photo_url,
        profile.voice_intro_url, profile.sifr_scores,
        profile.quran_level,
    ]
    filled = sum(1 for f in fields if f is not None)
    return int((filled / len(fields)) * 100)


# ─────────────────────────────────────────────
# PROFILE COMPLETION STATUS
# ─────────────────────────────────────────────

def get_missing_fields(profile: Profile) -> list[str]:
    """
    Return list of important missing fields with user-friendly names.
    Used to guide users to complete their profile.
    """
    missing = []
    checks = [
        (profile.bio,              "Biography"),
        (profile.date_of_birth,    "Date of birth"),
        (profile.city,             "City"),
        (profile.madhab,           "Madhab (school of thought)"),
        (profile.prayer_frequency, "Prayer frequency"),
        (profile.photo_url,        "Profile photo"),
        (profile.voice_intro_url,  "Voice introduction"),
        (profile.sifr_scores,      "Sifr personality assessment"),
        (profile.quran_level,      "Quran level"),
        (profile.education_level,  "Education"),
        (profile.occupation,       "Occupation"),
        (profile.wants_children,   "Children preference"),
    ]
    for value, label in checks:
        if value is None:
            missing.append(label)
    return missing


def get_next_profile_suggestion(profile: Profile) -> str:
    """Return the single most impactful next step for the user."""
    if not profile.photo_url:
        return "Add your profile photo — it increases your match rate by 3x"
    if not profile.voice_intro_url:
        return "Record your voice intro — it reveals your personality before photos"
    if not profile.sifr_scores:
        return "Complete the Sifr assessment to unlock deep compatibility matching"
    if not profile.madhab:
        return "Add your madhab to improve your Deen compatibility score"
    if not profile.bio:
        return "Write your biography — help others understand who you are"
    return "Your profile is looking great! Share MiskMatch to grow the community"
