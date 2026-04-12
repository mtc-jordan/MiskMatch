"""
MiskMatch — Games Router
Endpoints for the 17-game match engine.

REST:
    GET  /games/{match_id}                      → Game catalogue for a match
    POST /games/{match_id}/{game_type}/start    → Start a game
    GET  /games/{match_id}/{game_type}          → Get game state (resume)
    POST /games/{match_id}/{game_type}/turn     → Submit a turn (async games)
    POST /games/{match_id}/{game_type}/realtime → Submit real-time answer
    POST /games/{match_id}/time-capsule/seal    → Seal the Time Capsule
    POST /games/{match_id}/time-capsule/open    → Open the Time Capsule
    GET  /games/{match_id}/memory               → Match Memory timeline

WebSocket:
    WS   /games/ws/{match_id}                   → Real-time game events
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
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.database import get_db, AsyncSessionLocal
from app.core.security import decode_token
from app.core.websocket import manager
from app.games.engine import GAME_REGISTRY, GameMode
from app.models.models import User, UserStatus, Match, MatchStatus
from app.routers.auth import get_current_active_user
from app.services import games as game_svc

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/games", tags=["Games"])

CurrentUser = Annotated[User, Depends(get_current_active_user)]
DB          = Annotated[AsyncSession, Depends(get_db)]


class SubmitTurnRequest(BaseModel):
    answer: str = Field(..., min_length=1, max_length=2000)
    answer_data: Optional[dict] = None


class RealtimeAnswerRequest(BaseModel):
    question_id: str
    answer: str = Field(..., min_length=1, max_length=500)


# ─────────────────────────────────────────────
# GAME CATALOGUE
# ─────────────────────────────────────────────

@router.get("/{match_id}", summary="Game catalogue for a match")
async def get_game_catalogue(match_id: UUID, current_user: CurrentUser, db: DB):
    """All 17 games with unlock status, progress, and whose turn it is."""
    try:
        return await game_svc.get_game_catalogue(db, match_id, current_user.id)
    except ValueError as e:
        raise HTTPException(status_code=403, detail=str(e))


# ─────────────────────────────────────────────
# MATCH MEMORY TIMELINE  (before /{match_id}/{game_type} to avoid capture)
# ─────────────────────────────────────────────

@router.get("/{match_id}/memory", summary="Match Memory timeline")
async def get_memory_timeline(match_id: UUID, current_user: CurrentUser, db: DB):
    """
    The complete 'our story so far' chronicle.
    Games completed, milestones, days together.
    """
    try:
        return await game_svc.get_memory_timeline(db, match_id, current_user.id)
    except ValueError as e:
        raise HTTPException(status_code=403, detail=str(e))


# ─────────────────────────────────────────────
# START A GAME
# ─────────────────────────────────────────────

@router.post("/{match_id}/{game_type}/start", status_code=201, summary="Start a game")
async def start_game(match_id: UUID, game_type: str, current_user: CurrentUser, db: DB):
    """Start a new game session. Game must be unlocked by match day."""
    try:
        result = await game_svc.start_game(db, match_id, current_user.id, game_type)
        await db.commit()
        return result
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))


# ─────────────────────────────────────────────
# GET GAME STATE
# ─────────────────────────────────────────────

@router.get("/{match_id}/{game_type}", summary="Get game state (resume)")
async def get_game_state(match_id: UUID, game_type: str, current_user: CurrentUser, db: DB):
    """Current state of a game: turns history, current question, whose turn."""
    if game_type not in GAME_REGISTRY:
        raise HTTPException(status_code=404, detail=f"Unknown game type: '{game_type}'")
    try:
        return await game_svc.get_game_state(db, match_id, current_user.id, game_type)
    except ValueError as e:
        raise HTTPException(status_code=403, detail=str(e))


# ─────────────────────────────────────────────
# SUBMIT TURN  (async games)
# ─────────────────────────────────────────────

@router.post("/{match_id}/{game_type}/turn", summary="Submit a turn (async games)")
async def submit_turn(
    match_id: UUID, game_type: str, body: SubmitTurnRequest,
    current_user: CurrentUser, db: DB,
):
    """
    Submit your answer. Advances turn to other player.
    Valid for all ASYNC_TURN and COLLABORATIVE games.
    """
    meta = GAME_REGISTRY.get(game_type)
    if not meta:
        raise HTTPException(status_code=404, detail=f"Unknown game type: '{game_type}'")
    if meta["mode"] == GameMode.REAL_TIME:
        raise HTTPException(status_code=422, detail=f"Use /realtime for '{meta['name']}'.")

    try:
        result = await game_svc.submit_turn(
            db, match_id, current_user.id, game_type, body.answer, body.answer_data,
        )
        await db.commit()
        await manager.send_to_match(match_id, {"type": "game_turn", "payload": {"game_type": game_type, "result": result}})
        return result
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))


# ─────────────────────────────────────────────
# REAL-TIME ANSWER
# ─────────────────────────────────────────────

@router.post("/{match_id}/{game_type}/realtime", summary="Submit real-time answer")
async def submit_realtime(
    match_id: UUID, game_type: str, body: RealtimeAnswerRequest,
    current_user: CurrentUser, db: DB,
):
    """
    Both players answer simultaneously. Results hidden until both submit.
    On reveal, broadcasts to WebSocket.
    """
    if game_type not in GAME_REGISTRY:
        raise HTTPException(status_code=404, detail=f"Unknown game type: '{game_type}'")

    try:
        result = await game_svc.submit_realtime_answer(
            db, match_id, current_user.id, game_type, body.question_id, body.answer,
        )
        await db.commit()
        if result.get("both_answered"):
            await manager.send_to_match(match_id, {"type": "game_reveal", "payload": result})
        return result
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))


# ─────────────────────────────────────────────
# TIME CAPSULE
# ─────────────────────────────────────────────

@router.post("/{match_id}/time-capsule/seal", summary="Seal the Time Capsule")
async def seal_time_capsule(match_id: UUID, current_user: CurrentUser, db: DB):
    """Seal after both partners complete all 5 prompts. Locks for 30 days."""
    try:
        result = await game_svc.seal_capsule(db, match_id, current_user.id)
        await db.commit()
        await manager.send_to_match(match_id, {"type": "time_capsule_sealed", "payload": result})
        return result
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))


@router.post("/{match_id}/time-capsule/open", summary="Open the Time Capsule")
async def open_time_capsule(match_id: UUID, current_user: CurrentUser, db: DB):
    """Open after 30 days. Read each other's hearts. Alhamdulillah."""
    try:
        result = await game_svc.open_capsule(db, match_id, current_user.id)
        await db.commit()
        await manager.send_to_match(match_id, {"type": "time_capsule_opened", "payload": {"opened_at": result["opened_at"]}})
        return result
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))


# ─────────────────────────────────────────────
# WEBSOCKET — REAL-TIME EVENTS
# ─────────────────────────────────────────────

@router.websocket("/ws/{match_id}")
async def websocket_games(
    websocket: WebSocket,
    match_id: UUID,
):
    """
    Real-time game event stream.
    Listen here during real-time games for simultaneous answer reveals.
    All game actions are submitted via REST; results arrive here.

    Authentication — first-message auth:
        Connect without token, then send as first message:
        { "type": "authenticate", "payload": { "token": "<access_token>" } }
    """
    # ── Auth: first-message token exchange ──
    await websocket.accept()
    try:
        raw = await asyncio.wait_for(websocket.receive_text(), timeout=10.0)
        event = json.loads(raw)
        if event.get("type") != "authenticate" or not event.get("payload", {}).get("token"):
            await websocket.send_json({
                "type": "error",
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
        await websocket.close(code=4001, reason="Auth failed")
        return

    async with AsyncSessionLocal() as db:
        user_res  = await db.execute(select(User).where(User.id == user_id))
        user      = user_res.scalar_one_or_none()
        match_res = await db.execute(
            select(Match).where(Match.id == match_id, Match.status == MatchStatus.ACTIVE)
        )
        match = match_res.scalar_one_or_none()

        if not user or user.status != UserStatus.ACTIVE:
            await websocket.close(code=4003); return
        if not match or user_id not in [match.sender_id, match.receiver_id]:
            await websocket.close(code=4004); return

    await manager.connect(websocket, user_id, match_id, already_accepted=True)
    try:
        await websocket.send_json({
            "type": "game_connected",
            "payload": {"match_id": str(match_id)},
        })
        while True:
            raw = await websocket.receive_text()
            event = json.loads(raw)
            if event.get("type") == "ping":
                await websocket.send_json({"type": "pong", "payload": {}})
    except WebSocketDisconnect:
        logger.info(
            "Game WS disconnected: user=%s match=%s", user_id, match_id
        )
    except json.JSONDecodeError as e:
        logger.warning(
            "Game WS bad JSON from user=%s match=%s: %s", user_id, match_id, e
        )
    except Exception as e:
        logger.error(
            "Game WS unexpected error: user=%s match=%s: %s",
            user_id, match_id, e, exc_info=True,
        )
    finally:
        await manager.disconnect(user_id, match_id)
