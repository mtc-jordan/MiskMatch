"""
MiskMatch — Profiles Router
All profile-related endpoints.

Endpoints:
    GET  /profiles/me              → Get my full profile
    POST /profiles/me              → Create my profile
    PUT  /profiles/me              → Update my profile
    GET  /profiles/me/completion   → Profile completion status
    POST /profiles/me/photo        → Upload main photo
    POST /profiles/me/gallery      → Add gallery photo
    DELETE /profiles/me/gallery    → Remove gallery photo
    POST /profiles/me/voice        → Upload voice intro
    POST /profiles/me/quran        → Upload Quran recitation
    GET  /profiles/me/family       → Get family profile
    PUT  /profiles/me/family       → Upsert family profile
    POST /profiles/me/sifr         → Submit Sifr assessment
    PUT  /profiles/me/preferences  → Update search preferences
    GET  /profiles/{user_id}       → Get another user's public profile
"""

from typing import Annotated
from uuid import UUID

from fastapi import (
    APIRouter, Depends, HTTPException, UploadFile, File,
    status, Query,
)
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.database import get_db
from app.core.config import settings
from app.models.models import User, Profile, Family, UserStatus
from app.routers.auth import get_current_active_user
from app.schemas.profiles import (
    ProfileCreateRequest, ProfileUpdateRequest,
    FamilyUpsertRequest, SifrAssessmentRequest,
    SearchPreferencesRequest,
    ProfileResponse, PublicProfileResponse,
    FamilyResponse, PhotoUploadResponse,
    VoiceUploadResponse, ProfileCompletionResponse,
)
from app.services import profiles as profile_svc
from app.services import storage

router = APIRouter(prefix="/profiles", tags=["Profiles"])

# Type alias for clarity
CurrentUser = Annotated[User, Depends(get_current_active_user)]
DB          = Annotated[AsyncSession, Depends(get_db)]


# ─────────────────────────────────────────────
# MY PROFILE — READ
# ─────────────────────────────────────────────

@router.get(
    "/me",
    response_model=ProfileResponse,
    summary="Get my full profile",
)
async def get_my_profile(
    current_user: CurrentUser,
    db: DB,
):
    """
    Returns the authenticated user's full profile including family.
    This is the owner view — contains all fields.
    """
    profile = await profile_svc.get_profile_by_user_id(
        db, current_user.id, include_family=True
    )
    if not profile:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Profile not created yet. POST /profiles/me to create it.",
        )

    # Attach family if it exists
    family = await profile_svc.get_family_by_user_id(db, current_user.id)
    response = ProfileResponse.model_validate(profile)
    if family:
        response.family = FamilyResponse.model_validate(family)

    return response


# ─────────────────────────────────────────────
# MY PROFILE — CREATE
# ─────────────────────────────────────────────

@router.post(
    "/me",
    response_model=ProfileResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create my profile",
)
async def create_my_profile(
    body: ProfileCreateRequest,
    current_user: CurrentUser,
    db: DB,
):
    """
    Create the authenticated user's profile.
    Called once after registration + OTP verification.
    """
    try:
        profile = await profile_svc.create_profile(
            db, current_user.id, body
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(e),
        )

    await db.commit()
    return ProfileResponse.model_validate(profile)


# ─────────────────────────────────────────────
# MY PROFILE — UPDATE
# ─────────────────────────────────────────────

@router.put(
    "/me",
    response_model=ProfileResponse,
    summary="Update my profile",
)
async def update_my_profile(
    body: ProfileUpdateRequest,
    current_user: CurrentUser,
    db: DB,
):
    """
    Partial update of the authenticated user's profile.
    Only provided fields are updated — omitted fields are unchanged.
    """
    profile = await _get_profile_or_404(db, current_user.id)
    updated = await profile_svc.update_profile(db, profile, body)
    await db.commit()
    return ProfileResponse.model_validate(updated)


# ─────────────────────────────────────────────
# PROFILE COMPLETION STATUS
# ─────────────────────────────────────────────

@router.get(
    "/me/completion",
    response_model=ProfileCompletionResponse,
    summary="Get profile completion status",
)
async def get_completion(
    current_user: CurrentUser,
    db: DB,
):
    """
    Returns completion percentage, trust score, missing fields,
    and the single best next action for the user to take.
    """
    profile = await _get_profile_or_404(db, current_user.id)

    missing = profile_svc.get_missing_fields(profile)
    total_fields = 12
    filled = total_fields - len(missing)
    pct = int((filled / total_fields) * 100)

    return ProfileCompletionResponse(
        completion_pct=pct,
        trust_score=profile.trust_score,
        missing_fields=missing,
        next_suggestion=profile_svc.get_next_profile_suggestion(profile),
    )


# ─────────────────────────────────────────────
# PHOTO UPLOAD — MAIN PHOTO
# ─────────────────────────────────────────────

@router.post(
    "/me/photo",
    response_model=PhotoUploadResponse,
    summary="Upload main profile photo",
)
async def upload_main_photo(
    current_user: CurrentUser,
    db: DB,
    file: UploadFile = File(..., description="JPEG/PNG/WebP, max 10MB"),
):
    """
    Upload and set the user's main profile photo.

    - Image is processed and resized to max 800px
    - EXIF metadata stripped (privacy)
    - Stored encrypted in S3 (AES256)
    - Delivered via CloudFront CDN
    - Replaces any existing main photo
    """
    profile = await _get_profile_or_404(db, current_user.id)

    # Read file bytes
    file_bytes = await file.read()
    if not file_bytes:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Empty file uploaded",
        )

    # Upload to S3
    try:
        photo_url = await storage.upload_profile_photo(
            user_id=str(current_user.id),
            file_bytes=file_bytes,
            content_type=file.content_type or "image/jpeg",
            suffix="main",
        )
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except RuntimeError as e:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(e)
        )

    # Delete old main photo from S3 (cleanup)
    if profile.photo_url and not settings.is_development:
        old_key = storage.extract_s3_key_from_url(profile.photo_url)
        if old_key:
            await storage.delete_media(old_key, settings.S3_BUCKET_PROFILES)

    # Update profile
    updated_profile, _ = await profile_svc.set_main_photo(db, profile, photo_url)
    await db.commit()

    return PhotoUploadResponse(
        photo_url=photo_url,
        message="Profile photo updated successfully",
        trust_score=updated_profile.trust_score,
    )


# ─────────────────────────────────────────────
# PHOTO UPLOAD — GALLERY
# ─────────────────────────────────────────────

@router.post(
    "/me/gallery",
    response_model=PhotoUploadResponse,
    summary="Add a photo to gallery",
)
async def add_gallery_photo(
    current_user: CurrentUser,
    db: DB,
    file: UploadFile = File(...),
):
    """Add a photo to the user's gallery (max 10 photos total)."""
    profile = await _get_profile_or_404(db, current_user.id)

    photos = profile.photos or []
    if len(photos) >= 10:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Maximum 10 gallery photos allowed. Delete one to add more.",
        )

    file_bytes = await file.read()

    try:
        gallery_index = len(photos)
        photo_url = await storage.upload_profile_photo(
            user_id=str(current_user.id),
            file_bytes=file_bytes,
            content_type=file.content_type or "image/jpeg",
            suffix=f"gallery_{gallery_index}",
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except RuntimeError as e:
        raise HTTPException(status_code=503, detail=str(e))

    updated = await profile_svc.add_gallery_photo(db, profile, photo_url)
    await db.commit()

    return PhotoUploadResponse(
        photo_url=photo_url,
        message=f"Gallery photo added ({len(updated.photos)}/10)",
        trust_score=updated.trust_score,
    )


@router.delete(
    "/me/gallery",
    summary="Remove a photo from gallery",
    status_code=status.HTTP_200_OK,
)
async def remove_gallery_photo(
    photo_url: str,
    current_user: CurrentUser,
    db: DB,
):
    """Remove a specific photo from the gallery by URL."""
    profile = await _get_profile_or_404(db, current_user.id)

    try:
        updated = await profile_svc.remove_gallery_photo(db, profile, photo_url)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))

    # Delete from S3
    key = storage.extract_s3_key_from_url(photo_url)
    if key:
        await storage.delete_media(key, settings.S3_BUCKET_PROFILES)

    await db.commit()
    return {"message": "Photo removed", "photos_remaining": len(updated.photos or [])}


# ─────────────────────────────────────────────
# VOICE INTRO
# ─────────────────────────────────────────────

@router.post(
    "/me/voice",
    response_model=VoiceUploadResponse,
    summary="Upload voice introduction",
)
async def upload_voice_intro(
    current_user: CurrentUser,
    db: DB,
    file: UploadFile = File(
        ...,
        description="MP3/MP4/WebM/OGG, max 60 seconds, max 20MB"
    ),
):
    """
    Upload a 60-second voice introduction.

    The voice intro is the FIRST thing a potential match hears —
    before they even see photos. Personality before appearance.
    """
    profile = await _get_profile_or_404(db, current_user.id)

    file_bytes = await file.read()
    if not file_bytes:
        raise HTTPException(status_code=400, detail="Empty file")

    try:
        voice_url, duration = await storage.upload_voice_intro(
            user_id=str(current_user.id),
            file_bytes=file_bytes,
            content_type=file.content_type or "audio/mpeg",
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except RuntimeError as e:
        raise HTTPException(status_code=503, detail=str(e))

    # Delete old voice intro
    if profile.voice_intro_url:
        old_key = storage.extract_s3_key_from_url(profile.voice_intro_url)
        if old_key:
            await storage.delete_media(old_key, settings.S3_BUCKET_MEDIA)

    updated_profile, _ = await profile_svc.set_voice_intro(db, profile, voice_url)
    await db.commit()

    return VoiceUploadResponse(
        voice_intro_url=voice_url,
        duration_seconds=duration,
        message="Voice introduction uploaded. Personality first!",
    )


# ─────────────────────────────────────────────
# QURAN RECITATION
# ─────────────────────────────────────────────

@router.post(
    "/me/quran",
    summary="Upload Quran recitation sample",
)
async def upload_quran_recitation(
    current_user: CurrentUser,
    db: DB,
    file: UploadFile = File(..., description="Audio file, 30-90 seconds of recitation"),
):
    """
    Upload a Quran recitation sample.
    Used by the AI Tajweed model for Quran Recitation Matching.
    """
    profile = await _get_profile_or_404(db, current_user.id)

    file_bytes = await file.read()
    if not file_bytes:
        raise HTTPException(status_code=400, detail="Empty file")

    try:
        recitation_url = await storage.upload_quran_recitation(
            user_id=str(current_user.id),
            file_bytes=file_bytes,
            content_type=file.content_type or "audio/mpeg",
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except RuntimeError as e:
        raise HTTPException(status_code=503, detail=str(e))

    profile.quran_recitation_url = recitation_url
    await db.commit()

    return {
        "recitation_url": recitation_url,
        "message": "Quran recitation uploaded. Tajweed analysis in progress.",
        "note": "AI analysis takes 2-3 minutes. Check back soon for your tajweed level.",
    }


# ─────────────────────────────────────────────
# FAMILY PROFILE
# ─────────────────────────────────────────────

@router.get(
    "/me/family",
    response_model=FamilyResponse,
    summary="Get my family profile",
)
async def get_my_family(
    current_user: CurrentUser,
    db: DB,
):
    """Get the authenticated user's family profile section."""
    family = await profile_svc.get_family_by_user_id(db, current_user.id)
    if not family:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Family profile not created yet. PUT /profiles/me/family to create it.",
        )
    return FamilyResponse.model_validate(family)


@router.put(
    "/me/family",
    response_model=FamilyResponse,
    summary="Create or update family profile",
)
async def upsert_family(
    body: FamilyUpsertRequest,
    current_user: CurrentUser,
    db: DB,
):
    """
    Create or update the family profile section.
    Idempotent — safe to call multiple times.
    """
    # Ensure main profile exists first
    await _get_profile_or_404(db, current_user.id)

    family = await profile_svc.upsert_family(db, current_user.id, body)
    await db.commit()

    return FamilyResponse.model_validate(family)


# ─────────────────────────────────────────────
# SIFR ASSESSMENT
# ─────────────────────────────────────────────

@router.post(
    "/me/sifr",
    summary="Submit Sifr Islamic personality assessment",
)
async def submit_sifr(
    body: SifrAssessmentRequest,
    current_user: CurrentUser,
    db: DB,
):
    """
    Submit answers to the Sifr personality assessment.
    Results are scored across 5 Islamic dimensions and saved to profile.
    Feeds into the AI Deen Compatibility Engine.
    """
    profile = await _get_profile_or_404(db, current_user.id)

    updated = await profile_svc.save_sifr_results(db, profile, body.answers)
    await db.commit()

    return {
        "message": "Sifr assessment saved",
        "scores": updated.sifr_scores,
        "love_language": updated.love_language,
        "trust_score": updated.trust_score,
        "note": "Your compatibility matching is now significantly more accurate.",
    }


# ─────────────────────────────────────────────
# SEARCH PREFERENCES
# ─────────────────────────────────────────────

@router.put(
    "/me/preferences",
    summary="Update search preferences",
)
async def update_preferences(
    body: SearchPreferencesRequest,
    current_user: CurrentUser,
    db: DB,
):
    """Update the user's match discovery search preferences."""
    profile = await _get_profile_or_404(db, current_user.id)

    profile.min_age             = body.min_age
    profile.max_age             = body.max_age
    profile.preferred_countries = body.preferred_countries
    profile.max_distance_km     = body.max_distance_km

    await db.commit()

    return {
        "message": "Search preferences updated",
        "min_age": profile.min_age,
        "max_age": profile.max_age,
        "preferred_countries": profile.preferred_countries,
        "max_distance_km": profile.max_distance_km,
    }


# ─────────────────────────────────────────────
# PUBLIC PROFILE VIEW
# ─────────────────────────────────────────────

@router.get(
    "/{user_id}",
    response_model=PublicProfileResponse,
    summary="View another user's public profile",
)
async def get_public_profile(
    user_id: UUID,
    current_user: CurrentUser,
    db: DB,
):
    """
    View another user's profile.

    Privacy rules:
    - Last name shown as initial only ("A." not "Ahmed")
    - Photos hidden unless mutual match exists
    - Employer hidden
    - Exact location not shown (city only)

    The compatibility score (deen_score) is computed
    and injected into the response.
    """
    # Cannot view your own profile via this endpoint
    if user_id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Use GET /profiles/me to view your own profile",
        )

    # Fetch target profile
    profile = await profile_svc.get_profile_by_user_id(
        db, user_id, include_family=False
    )
    if not profile:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Profile not found",
        )

    # Check if target user is active
    result = await db.execute(
        select(User).where(User.id == user_id)
    )
    target_user = result.scalar_one_or_none()
    if not target_user or target_user.status != UserStatus.ACTIVE:
        raise HTTPException(status_code=404, detail="Profile not found")

    # Gender filter — only show opposite gender profiles
    if target_user.gender == current_user.gender:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Profile not found",
        )

    # Build public response
    response = PublicProfileResponse.model_validate(profile)

    # Set last name to initial only
    if profile.last_name:
        response.last_name_initial = profile.last_name[0].upper() + "."

    # Check if there's a mutual match → reveal photo
    has_mutual = await _check_mutual_match(db, current_user.id, user_id)
    if not has_mutual:
        response.photo_url = None  # Keep blurred until mutual interest

    # Inject compatibility score
    viewer_profile = await profile_svc.get_profile_by_user_id(
        db, current_user.id, include_family=False
    )
    if viewer_profile:
        response.deen_score = _quick_compatibility_score(
            viewer_profile, profile
        )

    return response


# ─────────────────────────────────────────────
# HELPERS (private)
# ─────────────────────────────────────────────

async def _get_profile_or_404(db: AsyncSession, user_id: UUID) -> Profile:
    """Get profile or raise 404. Used throughout the router."""
    profile = await profile_svc.get_profile_by_user_id(
        db, user_id, include_family=False
    )
    if not profile:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Profile not found. Create it first at POST /profiles/me",
        )
    return profile


async def _check_mutual_match(
    db: AsyncSession,
    user_a: UUID,
    user_b: UUID,
) -> bool:
    """
    Check if two users have a mutual/active match.
    Used to determine whether to reveal photos.
    """
    from app.models.models import Match, MatchStatus
    from sqlalchemy import or_, and_

    result = await db.execute(
        select(Match).where(
            and_(
                or_(
                    and_(Match.sender_id == user_a,   Match.receiver_id == user_b),
                    and_(Match.sender_id == user_b,   Match.receiver_id == user_a),
                ),
                Match.status.in_([
                    MatchStatus.MUTUAL,
                    MatchStatus.APPROVED,
                    MatchStatus.ACTIVE,
                ]),
            )
        )
    )
    return result.scalar_one_or_none() is not None


def _quick_compatibility_score(
    profile_a: Profile,
    profile_b: Profile,
) -> float:
    """
    Fast rule-based compatibility score for discovery feed.
    Phase 4 replaces this with the full AI embedding model.
    Returns 0-100.
    """
    score = 50.0  # baseline

    # Madhab compatibility
    if profile_a.madhab and profile_b.madhab:
        if profile_a.madhab == profile_b.madhab:
            score += 10
        elif profile_a.madhab != "other" and profile_b.madhab != "other":
            score += 5  # different but both specific = ok

    # Prayer frequency alignment
    freq_map = {
        "all_five": 5, "most": 4, "sometimes": 3,
        "friday_only": 2, "working_on": 1,
    }
    a_freq = freq_map.get(profile_a.prayer_frequency, 0)
    b_freq = freq_map.get(profile_b.prayer_frequency, 0)
    if a_freq and b_freq:
        diff = abs(a_freq - b_freq)
        if diff == 0:
            score += 15
        elif diff == 1:
            score += 8
        elif diff >= 3:
            score -= 10

    # Children preference
    if profile_a.wants_children is not None and profile_b.wants_children is not None:
        if profile_a.wants_children == profile_b.wants_children:
            score += 10
        else:
            score -= 15  # deal-breaker level difference

    # Hijra intention alignment
    if profile_a.wants_hijra is not None and profile_b.wants_hijra is not None:
        if profile_a.wants_hijra == profile_b.wants_hijra:
            score += 8

    # Revert compatibility
    if profile_a.is_revert != profile_b.is_revert:
        score -= 5  # slight reduction — not a dealbreaker

    # Trust score bonus (higher trust = better match quality)
    trust_avg = (profile_a.trust_score + profile_b.trust_score) / 2
    score += (trust_avg / 100) * 10

    return round(max(0.0, min(100.0, score)), 1)
