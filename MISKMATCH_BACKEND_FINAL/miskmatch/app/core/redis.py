"""
MiskMatch — Redis Client
Shared async Redis connection for token blacklist, rate limiting, caching.
"""

import logging
from typing import Optional

import redis.asyncio as aioredis

from app.core.config import settings

logger = logging.getLogger(__name__)

_redis: Optional[aioredis.Redis] = None


async def get_redis() -> aioredis.Redis:
    """Return a shared async Redis connection (lazy init)."""
    global _redis
    if _redis is None:
        _redis = await aioredis.from_url(
            settings.REDIS_URL,
            decode_responses=True,
            max_connections=settings.REDIS_MAX_CONNECTIONS,
            socket_connect_timeout=5,
            socket_timeout=5,
            retry_on_timeout=True,
        )
        logger.info("Redis connection established")
    return _redis


async def close_redis() -> None:
    """Gracefully close the Redis connection."""
    global _redis
    if _redis is not None:
        await _redis.close()
        _redis = None


# ─────────────────────────────────────────────
# Token Blacklist
# ─────────────────────────────────────────────
_BLACKLIST_PREFIX = "miskmatch:token:blacklist:"


async def blacklist_token(jti: str, ttl_seconds: int) -> None:
    """Add a token JTI to the blacklist with auto-expiry."""
    r = await get_redis()
    await r.setex(f"{_BLACKLIST_PREFIX}{jti}", ttl_seconds, "1")


async def is_token_blacklisted(jti: str) -> bool:
    """Check if a token JTI has been revoked."""
    r = await get_redis()
    return await r.exists(f"{_BLACKLIST_PREFIX}{jti}") > 0


async def blacklist_all_user_tokens(user_id: str) -> None:
    """
    Invalidate all tokens for a user by bumping their token version.
    Tokens issued before this version are considered invalid.
    """
    r = await get_redis()
    await r.incr(f"miskmatch:token:version:{user_id}")


async def get_user_token_version(user_id: str) -> int:
    """Get the current token version for a user (0 if none set)."""
    r = await get_redis()
    version = await r.get(f"miskmatch:token:version:{user_id}")
    return int(version) if version else 0


# ─────────────────────────────────────────────
# Rate Limiting (Redis-backed)
# ─────────────────────────────────────────────
_RATE_PREFIX = "miskmatch:ratelimit:"


async def check_rate_limit(key: str, max_requests: int, window_seconds: int) -> bool:
    """
    Sliding-window rate limiter using Redis sorted sets.
    Returns True if the request is ALLOWED, False if rate-limited.
    """
    import time
    r = await get_redis()
    now = time.time()
    redis_key = f"{_RATE_PREFIX}{key}"

    pipe = r.pipeline()
    # Remove entries outside the window
    pipe.zremrangebyscore(redis_key, 0, now - window_seconds)
    # Count current entries
    pipe.zcard(redis_key)
    # Add current request
    pipe.zadd(redis_key, {str(now): now})
    # Set TTL on the key
    pipe.expire(redis_key, window_seconds)
    results = await pipe.execute()

    current_count = results[1]
    return current_count < max_requests


# ─────────────────────────────────────────────
# Caching Layer
# ─────────────────────────────────────────────
_CACHE_PREFIX = "miskmatch:cache:"


async def cache_get(key: str) -> Optional[str]:
    """Get a cached value by key. Returns None on miss or Redis failure."""
    try:
        r = await get_redis()
        return await r.get(f"{_CACHE_PREFIX}{key}")
    except Exception:
        return None


async def cache_set(key: str, value: str, ttl_seconds: int = 300) -> None:
    """Set a cached value with TTL. Fails silently."""
    try:
        r = await get_redis()
        await r.setex(f"{_CACHE_PREFIX}{key}", ttl_seconds, value)
    except Exception:
        pass


async def cache_delete(key: str) -> None:
    """Delete a cached key. Fails silently."""
    try:
        r = await get_redis()
        await r.delete(f"{_CACHE_PREFIX}{key}")
    except Exception:
        pass


async def cache_delete_pattern(pattern: str) -> None:
    """Delete all keys matching a pattern. Fails silently."""
    try:
        r = await get_redis()
        cursor = 0
        full_pattern = f"{_CACHE_PREFIX}{pattern}"
        while True:
            cursor, keys = await r.scan(cursor=cursor, match=full_pattern, count=100)
            if keys:
                await r.delete(*keys)
            if cursor == 0:
                break
    except Exception:
        pass
