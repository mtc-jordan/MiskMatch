"""
MiskMatch — Background Embedding Tasks
Celery workers that keep profile embeddings up to date.

Tasks:
  embed_profile_task(user_id)       — embed a single profile (on create/update)
  reembed_stale_profiles_task()     — nightly: embed any profiles missing vectors
  reembed_all_profiles_task()       — admin: re-embed everything (model upgrade)

Triggered:
  - Profile created or updated → embed_profile_task fires immediately
  - Nightly cron at 02:00 UTC → reembed_stale_profiles_task
  - Admin POST /compatibility/admin/reembed → reembed_all_profiles_task
"""

import asyncio
import logging
from datetime import datetime, timezone
from uuid import UUID

from celery import Celery
from celery.schedules import crontab

from app.core.config import settings

logger = logging.getLogger(__name__)

# ── Celery app ────────────────────────────────────────────────────────────────
celery_app = Celery(
    "miskmatch",
    broker=settings.REDIS_URL,
    backend=settings.REDIS_URL,
)

celery_app.conf.update(
    task_serializer="json",
    result_serializer="json",
    accept_content=["json"],
    timezone="UTC",
    enable_utc=True,
    task_track_started=True,
    task_acks_late=True,                  # redeliver if worker crashes
    worker_prefetch_multiplier=1,         # fair distribution
    task_soft_time_limit=120,             # 2 min soft limit per task
    task_time_limit=180,                  # 3 min hard limit
)

# ── Periodic schedule ─────────────────────────────────────────────────────────
celery_app.conf.beat_schedule = {
    "nightly-stale-reembed": {
        "task": "app.workers.tasks.reembed_stale_profiles_task",
        "schedule": crontab(hour=2, minute=0),   # 02:00 UTC nightly
    },
}


# ─────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────

def _run_async(coro):
    """Run an async coroutine from a sync Celery task."""
    try:
        loop = asyncio.get_event_loop()
        if loop.is_running():
            import nest_asyncio
            nest_asyncio.apply()
            logger.debug("nest_asyncio: patching running event loop for Celery task")
            return loop.run_until_complete(coro)
        return loop.run_until_complete(coro)
    except RuntimeError as exc:
        logger.warning(f"Event loop unavailable ({exc}), falling back to asyncio.run()")
        return asyncio.run(coro)


async def _embed_and_store(user_id: UUID) -> bool:
    """Core async logic: load profile, embed, persist vector."""
    from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
    from sqlalchemy.orm import sessionmaker
    from sqlalchemy import select
    from app.models.models import Profile, User
    from app.services.embeddings import embed_profile, has_embedding

    engine = create_async_engine(settings.DATABASE_URL, echo=False)
    Session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    try:
        async with Session() as db:
            result = await db.execute(
                select(Profile).where(Profile.user_id == user_id)
            )
            profile = result.scalar_one_or_none()

            if not profile:
                logger.warning(f"embed_profile: profile not found for user {user_id}")
                return False

            vector = await embed_profile(profile)
            if not vector:
                logger.info(f"embed_profile: no vector returned for user {user_id} (no API key?)")
                return False

            profile.compatibility_embedding = vector
            await db.commit()

            logger.info(f"embed_profile: embedded user={user_id} ({len(vector)} dims)")
            return True
    finally:
        await engine.dispose()


# ─────────────────────────────────────────────
# TASKS
# ─────────────────────────────────────────────

@celery_app.task(
    name="app.workers.tasks.embed_profile_task",
    bind=True,
    max_retries=3,
    default_retry_delay=60,
)
def embed_profile_task(self, user_id: str) -> dict:
    """
    Embed a single user's profile.
    Triggered on: profile create, profile update.

    Auto-retries up to 3 times on failure (OpenAI rate limit, network error).
    """
    try:
        success = _run_async(_embed_and_store(UUID(user_id)))
        return {"success": success, "user_id": user_id}
    except Exception as exc:
        logger.error(f"embed_profile_task failed for {user_id}: {exc}")
        raise self.retry(exc=exc)


@celery_app.task(
    name="app.workers.tasks.reembed_stale_profiles_task",
    bind=True,
)
def reembed_stale_profiles_task(self) -> dict:
    """
    Nightly task: find all profiles without an embedding and embed them.
    Runs in small batches to avoid OpenAI rate limits.
    """
    async def _run():
        from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
        from sqlalchemy.orm import sessionmaker
        from sqlalchemy import select
        from app.models.models import Profile
        from app.services.embeddings import embed_profile

        engine = create_async_engine(settings.DATABASE_URL, echo=False)
        Session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

        embedded = 0
        failed   = 0
        BATCH    = 50

        try:
            async with Session() as db:
                # Find profiles missing or empty embedding
                result = await db.execute(
                    select(Profile).where(
                        Profile.compatibility_embedding.is_(None)
                    ).limit(BATCH)
                )
                profiles = result.scalars().all()

                for profile in profiles:
                    try:
                        vector = await embed_profile(profile)
                        if vector:
                            profile.compatibility_embedding = vector
                            embedded += 1
                        else:
                            failed += 1
                    except Exception as e:
                        logger.error(f"Failed to embed {profile.user_id}: {e}")
                        failed += 1
                    # Respect API rate limits between individual embeds
                    await asyncio.sleep(0.5)

                await db.commit()
        finally:
            await engine.dispose()

        logger.info(
            f"reembed_stale: embedded={embedded} failed={failed}"
        )
        return {"embedded": embedded, "failed": failed}

    return _run_async(_run())


@celery_app.task(
    name="app.workers.tasks.reembed_all_profiles_task",
    bind=True,
    soft_time_limit=3600,   # 1hr — large dataset
    time_limit=3900,
)
def reembed_all_profiles_task(self, batch_size: int = 100) -> dict:
    """
    Admin task: re-embed ALL profiles.
    Use after upgrading the embedding model.

    Rate-limited: 1s sleep between batches to respect OpenAI limits.
    Progress is reported via Celery task state.
    """
    import time

    async def _run():
        from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
        from sqlalchemy.orm import sessionmaker
        from sqlalchemy import select, func
        from app.models.models import Profile
        from app.services.embeddings import embed_profile

        engine = create_async_engine(settings.DATABASE_URL, echo=False)
        Session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

        total_embedded = 0
        total_failed   = 0
        offset         = 0

        try:
            # Get total count
            async with Session() as db:
                count_result = await db.execute(
                    select(func.count(Profile.id))
                )
                total = count_result.scalar() or 0

            logger.info(f"reembed_all: starting — {total} profiles to embed")

            while True:
                async with Session() as db:
                    result = await db.execute(
                        select(Profile).offset(offset).limit(batch_size)
                    )
                    batch = result.scalars().all()
                    if not batch:
                        break

                    for profile in batch:
                        try:
                            vector = await embed_profile(profile)
                            if vector:
                                profile.compatibility_embedding = vector
                                total_embedded += 1
                            else:
                                total_failed += 1
                        except Exception as e:
                            logger.error(f"Failed to embed {profile.user_id}: {e}")
                            total_failed += 1

                    await db.commit()
                    offset += batch_size

                    # Report progress
                    progress = round(offset / total * 100, 1) if total else 100
                    self.update_state(
                        state="PROGRESS",
                        meta={
                            "current":  offset,
                            "total":    total,
                            "percent":  progress,
                            "embedded": total_embedded,
                            "failed":   total_failed,
                        },
                    )

                # Respect OpenAI rate limits
                time.sleep(1)
        finally:
            await engine.dispose()
        return {
            "total":    total,
            "embedded": total_embedded,
            "failed":   total_failed,
        }

    return _run_async(_run())
