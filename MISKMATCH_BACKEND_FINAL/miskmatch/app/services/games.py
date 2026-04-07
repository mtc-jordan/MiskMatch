"""
MiskMatch — Games Service
All 17 games: async turn system, real-time reveals,
Time Capsule, Match Memory timeline.
State stored as JSONB on Match.game_states.
"""

import logging
from datetime import datetime, timezone
from typing import Optional
from uuid import UUID

from sqlalchemy import select, and_, or_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.models import Match, MatchStatus, Notification
from app.games.engine import (
    GAME_REGISTRY, QUESTION_BANKS, GameStatus,
    build_initial_state, next_turn, is_game_complete,
    seal_time_capsule, is_capsule_open, GameType,
)

logger = logging.getLogger(__name__)


# ─────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────

async def _get_active_match(db, match_id: UUID, user_id: UUID) -> Match:
    result = await db.execute(
        select(Match).where(
            and_(
                Match.id == match_id,
                Match.status == MatchStatus.ACTIVE,
                or_(Match.sender_id == user_id, Match.receiver_id == user_id),
            )
        )
    )
    match = result.scalar_one_or_none()
    if not match:
        raise ValueError("Match not found, not active, or you are not a participant.")
    return match


def _get_game_state(match: Match, game_type: str) -> Optional[dict]:
    if not match.game_states:
        return None
    return match.game_states.get(game_type)


def _set_game_state(match: Match, game_type: str, state: dict) -> None:
    if not match.game_states:
        match.game_states = {}
    from sqlalchemy.orm.attributes import flag_modified
    match.game_states[game_type] = state
    flag_modified(match, "game_states")


def _match_day(match: Match) -> int:
    if not match.became_mutual_at:
        return 0
    ts = match.became_mutual_at
    if ts.tzinfo is None:
        ts = ts.replace(tzinfo=timezone.utc)
    return max(0, (datetime.now(timezone.utc) - ts).days)


def _other_user(match: Match, user_id: UUID) -> UUID:
    return match.receiver_id if match.sender_id == user_id else match.sender_id


def _current_question(state: dict, game_type: str) -> Optional[dict]:
    questions = QUESTION_BANKS.get(game_type, [])
    if not questions:
        return None
    idx = state.get("current_q_idx", 0)
    return questions[idx] if idx < len(questions) else None


# ─────────────────────────────────────────────
# GAME CATALOGUE
# ─────────────────────────────────────────────

async def get_game_catalogue(db, match_id: UUID, user_id: UUID) -> dict:
    match = await _get_active_match(db, match_id, user_id)
    day = _match_day(match)
    game_states = match.game_states or {}

    games = []
    for gtype, meta in GAME_REGISTRY.items():
        state = game_states.get(gtype, {})
        status = state.get("status", GameStatus.NOT_STARTED)
        turn_n = state.get("turn_number", 0)
        my_turn = (
            state.get("current_turn") == str(user_id)
            and status in [GameStatus.IN_PROGRESS, GameStatus.AWAITING_TURN]
        )
        games.append({
            "type":           gtype,
            "name":           meta["name"],
            "name_ar":        meta["name_ar"],
            "description":    meta["description"],
            "category":       meta["category"],
            "mode":           meta["mode"],
            "icon":           meta["icon"],
            "unlock_day":     meta["unlock_day"],
            "unlocked":       meta["unlock_day"] <= day,
            "days_to_unlock": max(0, meta["unlock_day"] - day),
            "status":         status,
            "progress":       f"{turn_n}/{meta['turns']}",
            "my_turn":        my_turn,
            "sealed":         state.get("sealed", False),
            "opens_at":       state.get("opens_at"),
            "can_open": (
                is_capsule_open(state) if gtype == GameType.TIME_CAPSULE else False
            ),
        })

    from collections import defaultdict
    by_cat: dict = defaultdict(list)
    for g in games:
        by_cat[g["category"]].append(g)

    return {
        "match_id":       str(match_id),
        "match_day":      day,
        "total_unlocked": sum(1 for g in games if g["unlocked"]),
        "total_games":    len(games),
        "categories":     dict(by_cat),
        "my_turn_games":  [g for g in games if g.get("my_turn")],
    }


# ─────────────────────────────────────────────
# START A GAME
# ─────────────────────────────────────────────

async def start_game(db, match_id: UUID, user_id: UUID, game_type: str) -> dict:
    if game_type not in GAME_REGISTRY:
        raise ValueError(f"Unknown game type: '{game_type}'.")

    match = await _get_active_match(db, match_id, user_id)
    meta = GAME_REGISTRY[game_type]
    day = _match_day(match)

    if meta["unlock_day"] > day:
        days_left = meta["unlock_day"] - day
        raise ValueError(
            f"'{meta['name']}' unlocks on day {meta['unlock_day']} "
            f"({days_left} day{'s' if days_left != 1 else ''} to go)."
        )

    existing = _get_game_state(match, game_type)
    if existing and existing.get("status") in [
        GameStatus.IN_PROGRESS, GameStatus.AWAITING_TURN, GameStatus.SEALED,
    ]:
        raise ValueError(f"'{meta['name']}' is already in progress.")

    other_id = str(_other_user(match, user_id))
    state = build_initial_state(game_type, str(user_id), other_id)
    _set_game_state(match, game_type, state)
    await db.flush()

    await _notify(db, _other_user(match, user_id), match.id,
                  f"New game: {meta['name']}!", f"لعبة جديدة: {meta['name']}",
                  "Your match started a game. It's your turn!",
                  "بدأ مطابقك لعبة جديدة. الدور عليك!", "game_started")

    return {
        "game_type":      game_type,
        "name":           meta["name"],
        "icon":           meta["icon"],
        "status":         state["status"],
        "your_turn":      True,
        "first_question": _current_question(state, game_type),
        "total_turns":    meta["turns"],
    }


# ─────────────────────────────────────────────
# GET GAME STATE
# ─────────────────────────────────────────────

async def get_game_state(db, match_id: UUID, user_id: UUID, game_type: str) -> dict:
    match = await _get_active_match(db, match_id, user_id)
    state = _get_game_state(match, game_type)
    meta  = GAME_REGISTRY.get(game_type, {})

    if not state:
        return {
            "game_type": game_type,
            "status":    GameStatus.NOT_STARTED,
            "message":   f"'{meta.get('name', game_type)}' hasn't been started yet.",
        }

    uid     = str(user_id)
    my_turn = (
        state.get("current_turn") == uid
        and state.get("status") in [GameStatus.IN_PROGRESS, GameStatus.AWAITING_TURN]
    )

    return {
        "game_type":        game_type,
        "name":             meta.get("name", game_type),
        "icon":             meta.get("icon", "🎮"),
        "status":           state.get("status"),
        "turn_number":      state.get("turn_number", 0),
        "total_turns":      meta.get("turns", 10),
        "my_turn":          my_turn,
        "current_question": _current_question(state, game_type) if my_turn else None,
        "turns_history":    state.get("turns", []),
        "scores":           state.get("scores", {}),
        "sealed":           state.get("sealed", False),
        "opens_at":         state.get("opens_at"),
        "can_open": (
            is_capsule_open(state) if game_type == GameType.TIME_CAPSULE else False
        ),
        "completed_at": state.get("completed_at"),
    }


# ─────────────────────────────────────────────
# SUBMIT TURN  (async games)
# ─────────────────────────────────────────────

async def submit_turn(
    db, match_id: UUID, user_id: UUID, game_type: str,
    answer: str, answer_data: Optional[dict] = None,
) -> dict:
    if not answer or not answer.strip():
        raise ValueError("Answer cannot be empty.")

    match = await _get_active_match(db, match_id, user_id)
    state = _get_game_state(match, game_type)

    if not state:
        raise ValueError(f"'{game_type}' has not been started yet.")
    if state["status"] not in [GameStatus.IN_PROGRESS, GameStatus.AWAITING_TURN]:
        raise ValueError(f"Game is not accepting turns (status: {state['status']}).")

    uid = str(user_id)
    if state["current_turn"] != uid:
        raise ValueError("It is not your turn. Please wait for your match to respond.")

    q = _current_question(state, game_type)
    state["turns"].append({
        "turn_number":  state["turn_number"],
        "user_id":      uid,
        "question":     q,
        "answer":       answer.strip(),
        "answer_data":  answer_data or {},
        "submitted_at": datetime.now(timezone.utc).isoformat(),
    })

    other_id = str(_other_user(match, user_id))
    meta = GAME_REGISTRY.get(game_type, {})

    if is_game_complete(state, game_type):
        state["status"] = GameStatus.COMPLETED
        state["completed_at"] = datetime.now(timezone.utc).isoformat()
        _set_game_state(match, game_type, state)
        await _add_to_timeline(db, match, game_type, meta.get("name", game_type))
        await db.flush()
        return {
            "status":       "completed",
            "message":      f"Masha'Allah! '{meta.get('name', game_type)}' is complete!",
            "turns":        state["turns"],
            "completed_at": state["completed_at"],
        }

    state = next_turn(state, uid, other_id)
    state["status"] = GameStatus.AWAITING_TURN
    _set_game_state(match, game_type, state)

    await _notify(db, UUID(other_id), match.id,
                  f"Your turn in {meta.get('name', game_type)}",
                  f"دورك في {meta.get('name', game_type)}",
                  "Your match answered. It's your turn.",
                  "أجاب مطابقك. حان دورك.", "game_turn")
    await db.flush()

    return {
        "status":        "turn_submitted",
        "turn_number":   state["turn_number"],
        "next_player":   other_id,
        "next_question": _current_question(state, game_type),
        "your_answer":   answer.strip(),
        "progress":      f"{state['turn_number']}/{meta.get('turns', 10)}",
    }


# ─────────────────────────────────────────────
# REAL-TIME GAMES  (simultaneous reveal)
# ─────────────────────────────────────────────

async def submit_realtime_answer(
    db, match_id: UUID, user_id: UUID,
    game_type: str, question_id: str, answer: str,
) -> dict:
    match = await _get_active_match(db, match_id, user_id)
    state = _get_game_state(match, game_type)
    if not state:
        raise ValueError("Game not started.")

    uid      = str(user_id)
    other_id = str(_other_user(match, user_id))
    pkey     = f"pending_{question_id}"

    if pkey not in state:
        state[pkey] = {}
    state[pkey][uid] = {"answer": answer.strip(), "submitted_at": datetime.now(timezone.utc).isoformat()}

    both = other_id in state[pkey]
    result: dict = {"question_id": question_id, "your_answer": answer.strip(), "waiting_for_partner": not both}

    if both:
        partner = state[pkey][other_id]["answer"]
        result.update({"partner_answer": partner, "both_answered": True, "reveal": True})

        if game_type in [GameType.ISLAMIC_TRIVIA, GameType.GEOGRAPHY_RACE]:
            qs = {q["id"]: q for q in QUESTION_BANKS.get(game_type, [])}
            q  = qs.get(question_id, {})
            correct = str(q.get("a", "")).strip().lower()
            my_ok    = answer.strip().lower() == correct
            their_ok = partner.strip().lower() == correct
            if my_ok:    state["scores"][uid]      = state["scores"].get(uid, 0) + 1
            if their_ok: state["scores"][other_id] = state["scores"].get(other_id, 0) + 1
            result.update({"correct_answer": q.get("a"), "you_got_it": my_ok, "they_got_it": their_ok, "scores": state["scores"]})

        state["turn_number"]   = state.get("turn_number", 0) + 1
        state["current_q_idx"] = state.get("current_q_idx", 0) + 1
        del state[pkey]

        if is_game_complete(state, game_type):
            state["status"] = GameStatus.COMPLETED
            state["completed_at"] = datetime.now(timezone.utc).isoformat()
            result["game_complete"] = True
            meta = GAME_REGISTRY.get(game_type, {})
            await _add_to_timeline(db, match, game_type, meta.get("name", game_type))

    _set_game_state(match, game_type, state)
    await db.flush()
    return result


# ─────────────────────────────────────────────
# TIME CAPSULE
# ─────────────────────────────────────────────

async def seal_capsule(db, match_id: UUID, user_id: UUID) -> dict:
    match = await _get_active_match(db, match_id, user_id)
    state = _get_game_state(match, GameType.TIME_CAPSULE)

    if not state:
        raise ValueError("Time Capsule hasn't been started yet.")
    if state.get("sealed"):
        raise ValueError(f"Already sealed. Opens at {state.get('opens_at', '')[:10]}.")

    needed = GAME_REGISTRY[GameType.TIME_CAPSULE]["turns"]
    if len(state.get("turns", [])) < needed:
        raise ValueError(f"Both partners must complete all {needed} prompts first. ({len(state.get('turns', []))}/{needed} done)")

    state = seal_time_capsule(state)
    _set_game_state(match, GameType.TIME_CAPSULE, state)

    for uid in [match.sender_id, match.receiver_id]:
        await _notify(db, uid, match.id,
                      "⏳ Time Capsule sealed!", "تم إغلاق كبسولة الزمن!",
                      f"Opens on {state['opens_at'][:10]}.",
                      f"تُفتح في {state['opens_at'][:10]}.", "time_capsule_sealed")
    await db.flush()
    return {"status": "sealed", "opens_at": state["opens_at"], "message": "Sealed with bismillah. Open it together in 30 days."}


async def open_capsule(db, match_id: UUID, user_id: UUID) -> dict:
    match = await _get_active_match(db, match_id, user_id)
    state = _get_game_state(match, GameType.TIME_CAPSULE)

    if not state or not state.get("sealed"):
        raise ValueError("Time Capsule is not sealed.")
    if not is_capsule_open(state):
        raise ValueError(f"Not ready yet. Opens on {state.get('opens_at', '')[:10]}.")

    state["status"] = GameStatus.COMPLETED
    state["completed_at"] = datetime.now(timezone.utc).isoformat()
    _set_game_state(match, GameType.TIME_CAPSULE, state)
    await _add_to_timeline(db, match, GameType.TIME_CAPSULE, "Time Capsule")
    await db.flush()
    return {"status": "opened", "sealed_at": state.get("sealed_at"), "opened_at": state["completed_at"], "entries": state.get("turns", []), "message": "Alhamdulillah. Read each other's hearts."}


# ─────────────────────────────────────────────
# MATCH MEMORY TIMELINE
# ─────────────────────────────────────────────

async def get_memory_timeline(db, match_id: UUID, user_id: UUID) -> dict:
    match    = await _get_active_match(db, match_id, user_id)
    timeline = match.memory_timeline or []
    day      = _match_day(match)

    milestones = [{
        "type": "milestone", "event": "match_started",
        "title": "Your journey began", "title_ar": "بدأت رحلتكما",
        "icon": "🌱",
        "date": match.became_mutual_at.isoformat() if match.became_mutual_at else None,
    }]
    if match.sender_wali_approved and match.receiver_wali_approved:
        milestones.append({
            "type": "milestone", "event": "wali_approved",
            "title": "Both families gave their blessing",
            "title_ar": "باركت الأسرتان",
            "icon": "🤲", "date": None,
        })

    all_entries = sorted(milestones + timeline, key=lambda x: x.get("date") or "")
    return {
        "match_id":     str(match_id),
        "match_day":    day,
        "total_events": len(all_entries),
        "timeline":     all_entries,
        "summary": {
            "games_completed": sum(1 for e in timeline if e.get("type") == "game_completed"),
            "days_together":   day,
        },
    }


async def _add_to_timeline(db, match: Match, game_type: str, game_name: str) -> None:
    meta = GAME_REGISTRY.get(game_type, {})
    if not match.memory_timeline:
        match.memory_timeline = []
    from sqlalchemy.orm.attributes import flag_modified
    match.memory_timeline.append({
        "type":      "game_completed",
        "event":     "game_completed",
        "game_type": game_type,
        "title":     f"Completed: {game_name}",
        "title_ar":  f"أكملتما: {meta.get('name_ar', game_name)}",
        "icon":      meta.get("icon", "🎮"),
        "date":      datetime.now(timezone.utc).isoformat(),
        "category":  meta.get("category", ""),
    })
    flag_modified(match, "memory_timeline")
    await db.flush()


# ─────────────────────────────────────────────
# NOTIFICATION HELPER
# ─────────────────────────────────────────────

async def _notify(db, user_id: UUID, match_id, title: str, title_ar: str,
                  body: str, body_ar: str, ntype: str) -> None:
    db.add(Notification(
        user_id=user_id, title=title, title_ar=title_ar,
        body=body, body_ar=body_ar,
        notification_type=ntype,
        reference_id=match_id, reference_type="match",
    ))
    await db.flush()
