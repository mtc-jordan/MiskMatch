"""
MiskMatch — Compatibility Router
AI Deen Compatibility Engine endpoints.

GET  /compatibility/{match_id}           Full explained compatibility report
GET  /compatibility/preview/{user_id}    Preview compatibility before expressing interest
POST /compatibility/embed/me             Trigger re-embedding of my profile
GET  /compatibility/embed/status/{uid}   Check embedding status
POST /compatibility/admin/reembed        Admin: re-embed all profiles
GET  /compatibility/admin/reembed/{tid}  Admin: check re-embed job progress
"""

import logging
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select, and_, or_
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.models.models import (
    User, UserRole, Profile, Match, MatchStatus,
)
from app.routers.auth import get_current_active_user
from app.services.compatibility import (
    compute_hybrid_score, explain_compatibility, rank_candidates,
)
from app.services.embeddings import (
    embed_profile, build_profile_text,
    has_embedding, EMBEDDING_DIMS,
)

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/compatibility", tags=["AI Compatibility Engine"])

CurrentUser = Annotated[User, Depends(get_current_active_user)]
DB          = Annotated[AsyncSession, Depends(get_db)]


# ─────────────────────────────────────────────
# MATCH COMPATIBILITY — full explained report
# ─────────────────────────────────────────────

@router.get(
    "/{match_id}",
    summary="Full compatibility report for a match",
    description="""
Returns the complete AI compatibility analysis between two matched users.

Includes:
- **Hybrid score** (0-100): weighted blend of rule engine + AI embeddings
- **Rule score**: hard constraint and practice alignment breakdown
- **AI score**: embedding cosine similarity (semantic values alignment)
- **Insights**: natural-language compatibility cards for the Flutter UI
- **Dealbreaker detection**: if a fundamental incompatibility is found

Both participants in the match can view this. Walis with match access can also view.

The AI score captures nuanced alignment the rule engine cannot — two users who
both pray all five prayers but have very different Islamic values will score
differently here than two who genuinely align.
    """,
)
async def get_match_compatibility(
    match_id: UUID,
    current_user: CurrentUser,
    db: DB,
):
    # Verify match access
    match_result = await db.execute(
        select(Match).where(
            and_(
                Match.id == match_id,
                Match.status.in_([
                    MatchStatus.MUTUAL, MatchStatus.APPROVED,
                    MatchStatus.ACTIVE, MatchStatus.NIKAH,
                ]),
                or_(
                    Match.sender_id   == current_user.id,
                    Match.receiver_id == current_user.id,
                ),
            )
        )
    )
    match = match_result.scalar_one_or_none()
    if not match:
        raise HTTPException(
            status_code=404,
            detail="Match not found or you are not a participant.",
        )

    # Load both profiles
    sender_p = await db.execute(
        select(Profile).where(Profile.user_id == match.sender_id)
    )
    receiver_p = await db.execute(
        select(Profile).where(Profile.user_id == match.receiver_id)
    )
    sender_profile   = sender_p.scalar_one_or_none()
    receiver_profile = receiver_p.scalar_one_or_none()

    if not sender_profile or not receiver_profile:
        raise HTTPException(
            status_code=422,
            detail="One or both profiles are incomplete. Complete your profile to see compatibility.",
        )

    # Determine which profile is "mine" for the explanation framing
    my_profile    = sender_profile if match.sender_id == current_user.id else receiver_profile
    their_profile = receiver_profile if match.sender_id == current_user.id else sender_profile

    # Run hybrid engine
    result = compute_hybrid_score(my_profile, their_profile)
    explanation = explain_compatibility(result, str(current_user.gender))

    return {
        "match_id":    str(match_id),
        "score":       round(result.final_score, 1),
        "explanation": explanation,
        "raw": result.to_dict(),
        "note": (
            "AI analysis active — score includes deep Islamic values alignment."
            if result.has_ai else
            "Profiles are being analysed by AI. Check back soon for a richer score."
        ),
    }


# ─────────────────────────────────────────────
# PREVIEW — score before expressing interest
# ─────────────────────────────────────────────

@router.get(
    "/preview/{candidate_id}",
    summary="Preview compatibility before expressing interest",
    description="""
Shows compatibility with a candidate profile before sending an interest request.

Returns the same hybrid score and insights the match compatibility report would show,
but without creating a match record. Allows users to make an informed decision.

Note: last_name and photo are still privacy-protected at this stage.
    """,
)
async def preview_compatibility(
    candidate_id: UUID,
    current_user: CurrentUser,
    db: DB,
):
    # Load both profiles
    my_p = await db.execute(
        select(Profile).where(Profile.user_id == current_user.id)
    )
    my_profile = my_p.scalar_one_or_none()
    if not my_profile:
        raise HTTPException(
            status_code=422,
            detail="Please complete your profile before viewing compatibility.",
        )

    cand_p = await db.execute(
        select(Profile).where(Profile.user_id == candidate_id)
    )
    candidate_profile = cand_p.scalar_one_or_none()
    if not candidate_profile:
        raise HTTPException(status_code=404, detail="Candidate profile not found.")

    result = compute_hybrid_score(my_profile, candidate_profile)
    explanation = explain_compatibility(result, str(current_user.gender))

    return {
        "candidate_id": str(candidate_id),
        "score":        round(result.final_score, 1),
        "explanation":  explanation,
        "raw":          result.to_dict(),
    }


# ─────────────────────────────────────────────
# PROFILE EMBEDDING
# ─────────────────────────────────────────────

@router.post(
    "/embed/me",
    summary="Trigger re-embedding of my profile",
    description="""
Queues a background job to re-embed your profile with the AI engine.

Call this after significantly updating your profile (bio, life goals,
Sifr assessment) to ensure your compatibility scores reflect your
latest information.

In production: fires a Celery task. In dev without a Celery worker,
the embedding runs synchronously.
    """,
)
async def embed_my_profile(
    current_user: CurrentUser,
    db: DB,
    sync: bool = Query(
        default=False,
        description="Run synchronously (dev only — slow in production)",
    ),
):
    profile_result = await db.execute(
        select(Profile).where(Profile.user_id == current_user.id)
    )
    profile = profile_result.scalar_one_or_none()
    if not profile:
        raise HTTPException(
            status_code=422,
            detail="Profile not found. Please create your profile first.",
        )

    profile_text = build_profile_text(profile)
    if not profile_text.strip():
        raise HTTPException(
            status_code=422,
            detail="Profile is too incomplete to embed. Add more information first.",
        )

    if sync:
        # Synchronous path for development testing
        vector = await embed_profile(profile)
        if vector:
            profile.compatibility_embedding = vector
            await db.commit()
            return {
                "status":  "embedded",
                "dims":    len(vector),
                "message": "Profile embedded successfully.",
                "text_preview": profile_text[:200] + "..." if len(profile_text) > 200 else profile_text,
            }
        else:
            return {
                "status":  "skipped",
                "message": "OpenAI API key not configured. Set OPENAI_API_KEY to enable AI scoring.",
                "text_preview": profile_text[:200] + "..." if len(profile_text) > 200 else profile_text,
            }
    else:
        # Async path — fire Celery task
        try:
            from app.workers.tasks import embed_profile_task
            task = embed_profile_task.delay(str(current_user.id))
            return {
                "status":  "queued",
                "task_id": task.id,
                "message": "Embedding queued. Your compatibility scores will update shortly.",
            }
        except Exception as e:
            logger.warning(f"Celery unavailable, falling back to sync: {e}")
            vector = await embed_profile(profile)
            if vector:
                profile.compatibility_embedding = vector
                await db.commit()
                return {"status": "embedded_sync", "dims": len(vector)}
            return {"status": "skipped", "message": "Embedding unavailable."}


@router.get(
    "/embed/status/{user_id}",
    summary="Check embedding status for a profile",
)
async def get_embedding_status(
    user_id: UUID,
    current_user: CurrentUser,
    db: DB,
):
    """Check if a profile has been embedded and the embedding dimensions."""
    # Users can only check their own, admins can check any
    if current_user.id != user_id and current_user.role != UserRole.ADMIN:
        raise HTTPException(status_code=403, detail="You can only check your own embedding status.")

    profile_result = await db.execute(
        select(Profile).where(Profile.user_id == user_id)
    )
    profile = profile_result.scalar_one_or_none()
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found.")

    embedded = has_embedding(profile)
    text = build_profile_text(profile)

    return {
        "user_id":          str(user_id),
        "has_embedding":    embedded,
        "embedding_dims":   len(profile.compatibility_embedding) if embedded else 0,
        "expected_dims":    EMBEDDING_DIMS,
        "profile_text_len": len(text),
        "profile_text_preview": text[:300] + "..." if len(text) > 300 else text,
        "action": None if embedded else "POST /api/v1/compatibility/embed/me",
    }


# ─────────────────────────────────────────────
# ADMIN ENDPOINTS
# ─────────────────────────────────────────────

def _require_admin(user: User) -> User:
    if user.role != UserRole.ADMIN:
        raise HTTPException(
            status_code=403,
            detail="Admin access required.",
        )
    return user


@router.post(
    "/admin/reembed",
    summary="Admin: re-embed all profiles",
    description="""
Triggers a background job to re-embed all profiles in the database.

Use this after:
- Upgrading the embedding model
- Significantly changing the profile text builder
- Bulk importing new profiles

The job runs in batches of 100 with 1-second pauses between batches
to respect OpenAI rate limits. At 100k profiles, expect ~30 minutes.

Monitor progress via GET /compatibility/admin/reembed/{task_id}.
    """,
)
async def admin_reembed_all(
    current_user: CurrentUser,
    db: DB,
    batch_size: int = Query(default=100, ge=10, le=500),
):
    _require_admin(current_user)

    try:
        from app.workers.tasks import reembed_all_profiles_task
        task = reembed_all_profiles_task.delay(batch_size=batch_size)
        return {
            "status":     "queued",
            "task_id":    task.id,
            "batch_size": batch_size,
            "message":    "Re-embedding job queued. Monitor at /compatibility/admin/reembed/{task_id}",
        }
    except Exception as e:
        raise HTTPException(
            status_code=503,
            detail=f"Celery worker unavailable: {e}. Ensure the worker is running.",
        )


@router.get(
    "/admin/reembed/{task_id}",
    summary="Admin: check re-embed job progress",
)
async def admin_reembed_status(
    task_id: str,
    current_user: CurrentUser,
    db: DB,
):
    _require_admin(current_user)

    try:
        from celery.result import AsyncResult
        from app.workers.tasks import celery_app as app
        result = AsyncResult(task_id, app=app)

        response = {
            "task_id": task_id,
            "state":   result.state,
        }

        if result.state == "PROGRESS":
            response.update(result.info or {})
        elif result.state == "SUCCESS":
            response["result"] = result.get()
        elif result.state == "FAILURE":
            response["error"] = str(result.info)

        return response

    except Exception as e:
        raise HTTPException(
            status_code=503,
            detail=f"Cannot check task status: {e}",
        )


@router.get(
    "/admin/stats",
    summary="Admin: embedding coverage statistics",
)
async def admin_embedding_stats(
    current_user: CurrentUser,
    db: DB,
):
    """How many profiles have embeddings vs still need them."""
    _require_admin(current_user)

    from sqlalchemy import func

    total_result = await db.execute(
        select(func.count(Profile.id))
    )
    total = total_result.scalar() or 0

    embedded_result = await db.execute(
        select(func.count(Profile.id)).where(
            Profile.compatibility_embedding.isnot(None)
        )
    )
    embedded = embedded_result.scalar() or 0

    return {
        "total_profiles":    total,
        "embedded":          embedded,
        "pending":           total - embedded,
        "coverage_pct":      round(embedded / total * 100, 1) if total else 0,
        "embedding_model":   "text-embedding-3-small",
        "embedding_dims":    EMBEDDING_DIMS,
        "estimated_cost_usd": round((total - embedded) * 0.000015, 4),
        "action": (
            "POST /api/v1/compatibility/admin/reembed"
            if (total - embedded) > 0 else None
        ),
    }
