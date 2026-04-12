"""
MiskMatch — Messages Router
REST endpoints + WebSocket for supervised real-time chat.

REST Endpoints:
    GET  /messages/{match_id}         → Get paginated message history
    POST /messages/{match_id}         → Send a message (REST fallback)
    PUT  /messages/{match_id}/read    → Mark messages as read
    POST /messages/{match_id}/report  → Report a message
    GET  /messages/wali/conversations → Wali: all conversations summary
    GET  /messages/wali/{match_id}    → Wali: full conversation with moderation data

WebSocket:
    WS   /messages/ws/{match_id}      → Real-time bidirectional chat
"""

import asyncio
import json
import logging
from typing import Annotated, Optional
from uuid import UUID

from fastapi import (
    APIRouter, Depends, HTTPException, Query,
    WebSocket, WebSocketDisconnect, status,
)
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.database import get_db, AsyncSessionLocal
from app.core.security import decode_token
from app.core.websocket import manager
from app.models.models import User, Profile, Match, MatchStatus, UserStatus
from app.routers.auth import get_current_active_user
from app.schemas.messages import (
    SendMessageRequest, MessageResponse,
    MessageListResponse, MarkReadRequest,
    WSEventType, WSSendMessage,
)
from app.services import messages as msg_svc
from app.services.profiles import get_profile_by_user_id

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/messages", tags=["Messages"])

CurrentUser = Annotated[User, Depends(get_current_active_user)]
DB          = Annotated[AsyncSession, Depends(get_db)]


# ─────────────────────────────────────────────
# WEBSOCKET — REAL-TIME CHAT
# ─────────────────────────────────────────────

@router.websocket("/ws/{match_id}")
async def websocket_chat(
    websocket: WebSocket,
    match_id: UUID,
):
    """
    WebSocket endpoint for real-time chat.

    Authentication — first-message auth:
        Connect without token, then send as first message:
        { "type": "authenticate", "payload": { "token": "<access_token>" } }

    Client sends events:
        { "type": "authenticate", "payload": { "token": "..." } }  ← must be first message
        { "type": "send_message", "payload": { "content": "...", "content_type": "text" } }
        { "type": "mark_read", "payload": { "message_ids": ["uuid1", "uuid2"] } }
        { "type": "typing_start", "payload": {} }
        { "type": "typing_stop",  "payload": {} }
        { "type": "ping",         "payload": {} }

    Server sends events:
        { "type": "connected",    "payload": { "user_id": "...", "online_users": [...] } }
        { "type": "new_message",  "payload": { ...message data... } }
        { "type": "message_read", "payload": { "message_ids": [...] } }
        { "type": "typing",       "payload": { "user_id": "...", "typing": true } }
        { "type": "presence",     "payload": { "user_id": "...", "online": true } }
        { "type": "pong",         "payload": {} }
        { "type": "error",        "payload": { "message": "..." } }
    """
    # ── Auth: first-message token exchange ──
    await websocket.accept()
    try:
        raw = await asyncio.wait_for(websocket.receive_text(), timeout=10.0)
        event = json.loads(raw)
        if event.get("type") != "authenticate" or not event.get("payload", {}).get("token"):
            await websocket.send_json({
                "type": WSEventType.ERROR,
                "payload": {"message": "First message must be an authenticate event"},
            })
            await websocket.close(code=4001, reason="Authentication required")
            return
        token = event["payload"]["token"]
    except asyncio.TimeoutError:
        await websocket.close(code=4001, reason="Authentication timeout")
        return
    except (json.JSONDecodeError, Exception):
        await websocket.close(code=4001, reason="Invalid authentication message")
        return

    try:
        payload = decode_token(token)
        if payload.get("type") != "access":
            await websocket.close(code=4001, reason="Invalid token type")
            return
        user_id = UUID(payload["sub"])
    except Exception:
        await websocket.close(code=4001, reason="Authentication failed")
        return

    # ── Load user ─────────────────────────────
    async with AsyncSessionLocal() as db:
        user_result = await db.execute(
            select(User).where(User.id == user_id)
        )
        user = user_result.scalar_one_or_none()

        if not user or user.status != UserStatus.ACTIVE:
            await websocket.close(code=4003, reason="Account not active")
            return

        # ── Verify match access ───────────────
        match_result = await db.execute(
            select(Match).where(
                Match.id == match_id,
                Match.status == MatchStatus.ACTIVE,
            )
        )
        match = match_result.scalar_one_or_none()

        if not match or user_id not in [match.sender_id, match.receiver_id]:
            await websocket.close(code=4004, reason="Match not found or not active")
            return

        # Get user's display name
        profile_result = await db.execute(
            select(Profile).where(Profile.user_id == user_id)
        )
        profile = profile_result.scalar_one_or_none()
        display_name = profile.first_name if profile else "User"

    # ── Connect ───────────────────────────────
    await manager.connect(websocket, user_id, match_id, already_accepted=True)
    await manager.set_last_seen(user_id)

    # Send confirmation to the connecting client
    try:
        await websocket.send_json({
            "type": WSEventType.CONNECTED,
            "payload": {
                "user_id":      str(user_id),
                "match_id":     str(match_id),
                "online_users": manager.get_online_users(match_id),
                "message":      "Connected to MiskMatch chat. Bismillah.",
            },
        })
    except Exception:
        await manager.disconnect(user_id, match_id)
        return

    # ── Main message loop ─────────────────────
    try:
        while True:
            raw = await websocket.receive_text()

            try:
                event = json.loads(raw)
                event_type = event.get("type", "")
                payload    = event.get("payload", {})
            except (json.JSONDecodeError, AttributeError):
                await websocket.send_json({
                    "type": WSEventType.ERROR,
                    "payload": {"message": "Invalid JSON"},
                })
                continue

            # ── Handle event types ────────────

            if event_type == WSEventType.PING:
                await websocket.send_json({"type": WSEventType.PONG, "payload": {}})

            elif event_type == WSEventType.SEND_MESSAGE:
                await _handle_send_message(
                    websocket, user_id, match_id, display_name,
                    payload, match,
                )

            elif event_type == WSEventType.MARK_READ:
                await _handle_mark_read(
                    user_id, match_id, payload
                )

            elif event_type == WSEventType.TYPING_START:
                await manager.set_typing(match_id, user_id, display_name, True)

            elif event_type == WSEventType.TYPING_STOP:
                await manager.set_typing(match_id, user_id, display_name, False)

            else:
                await websocket.send_json({
                    "type": WSEventType.ERROR,
                    "payload": {"message": f"Unknown event type: {event_type}"},
                })

    except WebSocketDisconnect:
        logger.info(f"WS disconnect: user={user_id} match={match_id}")
    except Exception as e:
        logger.error(f"WS error: user={user_id} match={match_id} error={e}")
    finally:
        await manager.disconnect(user_id, match_id)
        await manager.set_last_seen(user_id)


async def _handle_send_message(
    websocket: WebSocket,
    sender_id: UUID,
    match_id: UUID,
    sender_name: str,
    payload: dict,
    match: Match,
) -> None:
    """Handle a send_message WebSocket event."""
    content      = payload.get("content", "").strip()
    content_type = payload.get("content_type", "text")
    media_url    = payload.get("media_url")

    if not content:
        await websocket.send_json({
            "type": WSEventType.ERROR,
            "payload": {"message": "Message content cannot be empty"},
        })
        return

    if len(content) > 2000:
        await websocket.send_json({
            "type": WSEventType.ERROR,
            "payload": {"message": "Message too long (max 2000 characters)"},
        })
        return

    # Save message + run moderation
    async with AsyncSessionLocal() as db:
        try:
            msg, was_blocked = await msg_svc.send_message(
                db=db,
                sender_id=sender_id,
                match_id=match_id,
                content=content,
                content_type=content_type,
                media_url=media_url,
            )
            await db.commit()

            if was_blocked:
                # Notify sender only — don't broadcast blocked message
                await websocket.send_json({
                    "type": WSEventType.MODERATION,
                    "payload": {
                        "message": (
                            "Your message was not delivered. "
                            "Please keep conversations within Islamic guidelines."
                        ),
                        "tip": "Your guardian has been notified.",
                    },
                })
                return

            # Broadcast to all participants in the match
            await manager.send_to_match(match_id, {
                "type": WSEventType.NEW_MESSAGE,
                "payload": {
                    "id":           str(msg.id),
                    "match_id":     str(match_id),
                    "sender_id":    str(sender_id),
                    "sender_name":  sender_name,
                    "content":      msg.content,
                    "content_type": msg.content_type,
                    "media_url":    msg.media_url,
                    "status":       msg.status,
                    "created_at":   msg.created_at.isoformat(),
                },
            })

        except ValueError as e:
            await websocket.send_json({
                "type": WSEventType.ERROR,
                "payload": {"message": str(e)},
            })


async def _handle_mark_read(
    reader_id: UUID,
    match_id: UUID,
    payload: dict,
) -> None:
    """Handle a mark_read WebSocket event."""
    raw_ids = payload.get("message_ids", [])
    if not raw_ids:
        return

    try:
        message_ids = [UUID(mid) for mid in raw_ids]
    except ValueError:
        return

    async with AsyncSessionLocal() as db:
        count = await msg_svc.mark_messages_read(db, match_id, reader_id, message_ids)
        await db.commit()

        if count > 0:
            # Notify match that messages were read
            await manager.send_to_match(match_id, {
                "type": WSEventType.MESSAGE_READ,
                "payload": {
                    "reader_id":   str(reader_id),
                    "message_ids": [str(mid) for mid in message_ids],
                    "count":       count,
                },
            })


# ─────────────────────────────────────────────
# REST — GET MESSAGES
# ─────────────────────────────────────────────

@router.get(
    "/{match_id}",
    response_model=MessageListResponse,
    summary="Get paginated message history",
)
async def get_messages(
    match_id: UUID,
    current_user: CurrentUser,
    db: DB,
    page: int      = Query(1, ge=1),
    page_size: int = Query(50, ge=10, le=100),
    before_id: Optional[UUID] = Query(
        None,
        description="Cursor: fetch messages before this message ID (infinite scroll)",
    ),
):
    """
    Get message history for a match.

    Access rules:
    - Participants see all non-flagged messages
    - Walis see all messages including flagged ones (via /messages/wali/{match_id})

    Newest messages first. Use before_id for infinite scroll pagination.
    """
    try:
        messages, total = await msg_svc.get_messages(
            db=db,
            match_id=match_id,
            user_id=current_user.id,
            page=page,
            page_size=page_size,
            before_id=before_id,
        )
    except ValueError as e:
        raise HTTPException(status_code=403, detail=str(e))

    # Batch-load sender names to avoid N+1
    sender_ids = {msg.sender_id for msg in messages}
    profiles_result = await db.execute(
        select(Profile).where(Profile.user_id.in_(sender_ids))
    )
    name_map = {p.user_id: p.first_name for p in profiles_result.scalars().all()}

    responses = []
    for msg in messages:
        responses.append(MessageResponse(
            id=msg.id,
            match_id=msg.match_id,
            sender_id=msg.sender_id,
            content=msg.content,
            content_type=msg.content_type,
            media_url=msg.media_url,
            status=msg.status,
            created_at=msg.created_at,
            updated_at=msg.updated_at,
            sender_name=name_map.get(msg.sender_id, "User"),
        ))

    return MessageListResponse(
        messages=responses,
        total=total,
        page=page,
        has_more=len(messages) == page_size,
        match_id=match_id,
    )


# ─────────────────────────────────────────────
# REST — SEND MESSAGE (fallback for no WS)
# ─────────────────────────────────────────────

@router.post(
    "/{match_id}",
    response_model=MessageResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Send a message (REST fallback)",
)
async def send_message_rest(
    match_id: UUID,
    body: SendMessageRequest,
    current_user: CurrentUser,
    db: DB,
):
    """
    REST fallback for sending messages.
    Use the WebSocket endpoint for real-time chat.
    This endpoint is for offline/background send scenarios.
    """
    try:
        msg, was_blocked = await msg_svc.send_message(
            db=db,
            sender_id=current_user.id,
            match_id=match_id,
            content=body.content,
            content_type=body.content_type,
            media_url=body.media_url,
        )
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))

    await db.commit()

    if was_blocked:
        raise HTTPException(
            status_code=422,
            detail=(
                "Message not delivered — content did not meet Islamic "
                "communication guidelines."
            ),
        )

    # Broadcast via WebSocket to any connected clients
    profile = await get_profile_by_user_id(db, current_user.id)
    sender_name = profile.first_name if profile else "User"

    await manager.send_to_match(match_id, {
        "type": WSEventType.NEW_MESSAGE,
        "payload": {
            "id":           str(msg.id),
            "match_id":     str(match_id),
            "sender_id":    str(current_user.id),
            "sender_name":  sender_name,
            "content":      msg.content,
            "content_type": msg.content_type,
            "media_url":    msg.media_url,
            "status":       msg.status,
            "created_at":   msg.created_at.isoformat(),
        },
    })

    return MessageResponse(
        id=msg.id,
        match_id=msg.match_id,
        sender_id=msg.sender_id,
        content=msg.content,
        content_type=msg.content_type,
        media_url=msg.media_url,
        status=msg.status,
        created_at=msg.created_at,
        updated_at=msg.updated_at,
        sender_name=sender_name,
    )


# ─────────────────────────────────────────────
# REST — MARK READ
# ─────────────────────────────────────────────

@router.put(
    "/{match_id}/read",
    summary="Mark messages as read",
)
async def mark_read(
    match_id: UUID,
    body: MarkReadRequest,
    current_user: CurrentUser,
    db: DB,
):
    """Mark specific messages as read. Triggers read receipts for the sender."""
    # Verify user is a participant in this match
    match_result = await db.execute(
        select(Match).where(
            Match.id == match_id,
            (Match.sender_id == current_user.id) | (Match.receiver_id == current_user.id),
        )
    )
    if not match_result.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="Match not found.")

    count = await msg_svc.mark_messages_read(
        db=db,
        match_id=match_id,
        reader_id=current_user.id,
        message_ids=body.message_ids,
    )
    await db.commit()

    if count > 0:
        await manager.send_to_match(match_id, {
            "type": WSEventType.MESSAGE_READ,
            "payload": {
                "reader_id":   str(current_user.id),
                "message_ids": [str(mid) for mid in body.message_ids],
                "count":       count,
            },
        })

    return {"marked_read": count}


# ─────────────────────────────────────────────
# REST — REPORT MESSAGE
# ─────────────────────────────────────────────

@router.post(
    "/{match_id}/report",
    summary="Report an inappropriate message",
)
async def report_message(
    match_id: UUID,
    message_id: UUID,
    current_user: CurrentUser,
    db: DB,
    reason: str = Query(..., min_length=10, max_length=200),
):
    """Flag a specific message for admin review."""
    try:
        await msg_svc.report_message(db, message_id, current_user.id, reason)
        await db.commit()
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))

    return {"message": "Report submitted. Our team will review within 24 hours."}


# ─────────────────────────────────────────────
# WALI PORTAL — CONVERSATIONS OVERVIEW
# ─────────────────────────────────────────────

@router.get(
    "/wali/conversations",
    summary="Wali: all conversations summary",
)
async def wali_conversations(
    current_user: CurrentUser,
    db: DB,
):
    """
    Returns a summary of all conversations the wali has visibility into.
    Shows message count, flagged count, last message, and match status.
    Designed for the Wali Portal dashboard.
    """
    summaries = await msg_svc.get_wali_conversations(db, current_user.id)
    return {
        "conversation_count": len(summaries),
        "conversations":      summaries,
    }


# ─────────────────────────────────────────────
# WALI PORTAL — FULL CONVERSATION
# ─────────────────────────────────────────────

@router.get(
    "/wali/{match_id}",
    summary="Wali: full conversation with moderation data",
)
async def wali_read_conversation(
    match_id: UUID,
    current_user: CurrentUser,
    db: DB,
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=10, le=100),
):
    """
    Guardian reads the full conversation including flagged messages
    and moderation reasons. Wali sees everything.

    Only accessible to registered, accepted walis for either participant.
    """
    try:
        messages, total = await msg_svc.get_wali_messages(
            db=db,
            match_id=match_id,
            wali_user_id=current_user.id,
            page=page,
            page_size=page_size,
        )
        # Mark this conversation as read by the wali
        await msg_svc.mark_wali_conversation_read(db, match_id, current_user.id)
    except ValueError as e:
        raise HTTPException(status_code=403, detail=str(e))

    # Batch-load sender names to avoid N+1
    sender_ids = {msg.sender_id for msg in messages}
    profiles_result = await db.execute(
        select(Profile).where(Profile.user_id.in_(sender_ids))
    )
    name_map = {p.user_id: p.first_name for p in profiles_result.scalars().all()}

    enriched = []
    for msg in messages:
        enriched.append({
            "id":                str(msg.id),
            "sender_id":         str(msg.sender_id),
            "sender_name":       name_map.get(msg.sender_id, "User"),
            "content":           msg.content,
            "content_type":      msg.content_type,
            "status":            msg.status,
            "created_at":        msg.created_at.isoformat(),
            "is_flagged":        msg.status == "flagged",
            "moderation_passed": msg.moderation_passed,
            "moderation_reason": msg.moderation_reason,
        })

    flagged_count = sum(1 for m in enriched if m["is_flagged"])

    return {
        "match_id":     str(match_id),
        "total":        total,
        "page":         page,
        "has_more":     (page * page_size) < total,
        "flagged_count": flagged_count,
        "messages":     enriched,
        "note":         (
            "You are viewing this conversation as a guardian. "
            "All messages including flagged ones are visible to you."
        ),
    }
