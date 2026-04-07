"""
MiskMatch — WebSocket Connection Manager
Manages active WebSocket connections with Redis pub/sub for
multi-instance horizontal scaling.

Architecture:
  Flutter app ──WS──► FastAPI instance A ──► Redis pub/sub ──► FastAPI instance B ──WS──► Flutter app
                                                   │
                                          All instances subscribe
                                          to match-specific channels.
"""

import asyncio
import json
import logging
from collections import defaultdict
from datetime import datetime, timezone
from typing import Optional
from uuid import UUID

from fastapi import WebSocket
import redis.asyncio as aioredis

from app.core.config import settings

logger = logging.getLogger(__name__)

# Redis channel prefix for match conversations
CHANNEL_PREFIX = "miskmatch:chat:"

# Typing indicator TTL (seconds)
TYPING_TTL = 5


class ConnectionManager:
    """
    Manages WebSocket connections for the chat system.

    Each WebSocket connection is registered per (user_id, match_id).
    Messages are broadcast via Redis pub/sub so that multiple
    FastAPI instances can serve the same conversation.

    Local connections dict:
        match_id → { user_id → WebSocket }
    """

    def __init__(self):
        # Local in-memory connections for this instance
        # match_id (str) → { user_id (str) → WebSocket }
        self._connections: dict[str, dict[str, WebSocket]] = defaultdict(dict)

        # Redis async client (lazy init)
        self._redis: Optional[aioredis.Redis] = None

        # Background subscriber task
        self._subscriber_task: Optional[asyncio.Task] = None

    async def get_redis(self) -> aioredis.Redis:
        """Lazy-init Redis connection."""
        if self._redis is None:
            self._redis = await aioredis.from_url(
                settings.REDIS_URL,
                encoding="utf-8",
                decode_responses=True,
            )
        return self._redis

    # ─────────────────────────────────────────
    # Connection lifecycle
    # ─────────────────────────────────────────

    async def connect(
        self,
        websocket: WebSocket,
        user_id: UUID,
        match_id: UUID,
    ) -> None:
        """
        Accept a WebSocket connection and register it.
        Publishes a presence event to the Redis channel.
        """
        await websocket.accept()

        uid  = str(user_id)
        mid  = str(match_id)

        # Register locally
        self._connections[mid][uid] = websocket

        # Subscribe to Redis channel for this match (if not already)
        await self._ensure_subscribed(mid)

        # Publish presence: user is online
        await self._publish(mid, {
            "type": "presence",
            "payload": {
                "user_id": uid,
                "online":  True,
                "at":      datetime.now(timezone.utc).isoformat(),
            },
        })

        logger.info(f"WS connected: user={uid} match={mid}")

    async def disconnect(
        self,
        user_id: UUID,
        match_id: UUID,
    ) -> None:
        """
        Remove a connection and publish offline presence.
        """
        uid = str(user_id)
        mid = str(match_id)

        self._connections[mid].pop(uid, None)
        if not self._connections[mid]:
            del self._connections[mid]

        try:
            redis = await self.get_redis()
            await self._publish(mid, {
                "type": "presence",
                "payload": {
                    "user_id": uid,
                    "online":  False,
                    "at":      datetime.now(timezone.utc).isoformat(),
                },
            })
        except Exception:
            pass  # Presence on disconnect is best-effort

        logger.info(f"WS disconnected: user={uid} match={mid}")

    # ─────────────────────────────────────────
    # Sending messages
    # ─────────────────────────────────────────

    async def send_to_match(
        self,
        match_id: UUID,
        event: dict,
        exclude_user: Optional[UUID] = None,
    ) -> None:
        """
        Broadcast an event to all participants in a match.
        Goes through Redis so all FastAPI instances receive it.
        """
        await self._publish(str(match_id), event)

    async def send_to_user(
        self,
        user_id: UUID,
        match_id: UUID,
        event: dict,
    ) -> None:
        """Send an event to a specific user in a specific match."""
        uid = str(user_id)
        mid = str(match_id)

        ws = self._connections.get(mid, {}).get(uid)
        if ws:
            try:
                await ws.send_json(event)
            except Exception as e:
                logger.warning(f"Failed to send to {uid}: {e}")
                await self.disconnect(user_id, match_id)

    async def _publish(self, match_id: str, event: dict) -> None:
        """Publish an event to the Redis pub/sub channel for a match."""
        try:
            redis = await self.get_redis()
            channel = f"{CHANNEL_PREFIX}{match_id}"
            await redis.publish(channel, json.dumps(event))
        except Exception as e:
            logger.error(f"Redis publish failed for match {match_id}: {e}")
            # Fallback: deliver locally if Redis is down
            await self._deliver_locally(match_id, event)

    async def _deliver_locally(self, match_id: str, event: dict) -> None:
        """
        Fallback: deliver directly to local WebSocket connections.
        Used when Redis is unavailable (dev without Redis, etc.).
        """
        local_connections = dict(self._connections.get(match_id, {}))
        for uid, ws in local_connections.items():
            try:
                await ws.send_json(event)
            except Exception:
                self._connections.get(match_id, {}).pop(uid, None)

    # ─────────────────────────────────────────
    # Redis subscriber
    # ─────────────────────────────────────────

    async def _ensure_subscribed(self, match_id: str) -> None:
        """
        Start the Redis subscriber background task if not running.
        One subscriber task handles all channels for this instance.
        """
        if self._subscriber_task is None or self._subscriber_task.done():
            self._subscriber_task = asyncio.create_task(
                self._redis_subscriber_loop()
            )

    async def _redis_subscriber_loop(self) -> None:
        """
        Background task: subscribes to all match channels and
        delivers incoming Redis messages to local WebSocket connections.
        """
        try:
            redis = await self.get_redis()
            pubsub = redis.pubsub()

            # Subscribe to pattern for all match channels
            await pubsub.psubscribe(f"{CHANNEL_PREFIX}*")
            logger.info("Redis pub/sub subscriber started")

            async for message in pubsub.listen():
                if message["type"] not in ("pmessage", "message"):
                    continue

                try:
                    channel = message.get("channel", "")
                    match_id = channel.replace(CHANNEL_PREFIX, "")
                    event = json.loads(message["data"])
                    await self._deliver_locally(match_id, event)
                except Exception as e:
                    logger.error(f"Subscriber error: {e}")

        except Exception as e:
            logger.error(f"Redis subscriber crashed: {e}")
            # Retry after 5 seconds
            await asyncio.sleep(5)

    # ─────────────────────────────────────────
    # Typing indicators
    # ─────────────────────────────────────────

    async def set_typing(
        self,
        match_id: UUID,
        user_id: UUID,
        user_name: str,
        typing: bool,
    ) -> None:
        """Broadcast a typing indicator to the match channel."""
        await self._publish(str(match_id), {
            "type": "typing",
            "payload": {
                "match_id":  str(match_id),
                "user_id":   str(user_id),
                "user_name": user_name,
                "typing":    typing,
            },
        })

    # ─────────────────────────────────────────
    # Presence
    # ─────────────────────────────────────────

    def is_online(self, user_id: UUID, match_id: UUID) -> bool:
        """Check if a user has an active WebSocket in this match."""
        return str(user_id) in self._connections.get(str(match_id), {})

    def get_online_users(self, match_id: UUID) -> list[str]:
        """Return list of online user IDs in a match."""
        return list(self._connections.get(str(match_id), {}).keys())

    async def set_last_seen(self, user_id: UUID) -> None:
        """Store last seen timestamp in Redis."""
        try:
            redis = await self.get_redis()
            await redis.setex(
                f"miskmatch:presence:{user_id}",
                3600,  # 1 hour TTL
                datetime.now(timezone.utc).isoformat(),
            )
        except Exception:
            pass

    async def get_last_seen(self, user_id: UUID) -> Optional[str]:
        """Retrieve last seen timestamp from Redis."""
        try:
            redis = await self.get_redis()
            return await redis.get(f"miskmatch:presence:{user_id}")
        except Exception:
            return None


# ─────────────────────────────────────────────
# Singleton instance
# ─────────────────────────────────────────────
manager = ConnectionManager()
