"""MiskMatch — Games Engine Tests"""

import pytest
from datetime import datetime, timezone, timedelta
from unittest.mock import MagicMock, AsyncMock
from uuid import uuid4

from app.games.engine import (
    GAME_REGISTRY, QUESTION_BANKS, GameType, GameStatus, GameMode,
    build_initial_state, next_turn, is_game_complete,
    seal_time_capsule, is_capsule_open, get_unlocked_games,
)
from app.models.models import Match, MatchStatus


class TestGameRegistry:

    def test_all_17_games_registered(self):
        assert len(GAME_REGISTRY) == 17

    def test_all_game_types_have_entry(self):
        for gtype in GameType:
            assert gtype in GAME_REGISTRY, f"Missing: {gtype}"

    def test_required_fields_present(self):
        required = {"name", "name_ar", "description", "category", "mode", "unlock_day", "turns", "icon"}
        for gtype, meta in GAME_REGISTRY.items():
            assert not (required - set(meta.keys())), f"{gtype} missing fields"

    def test_36_questions_has_36(self):
        assert len(QUESTION_BANKS[GameType.THIRTY_SIX_Q]) == 36

    def test_deal_or_no_deal_has_12(self):
        assert len(QUESTION_BANKS[GameType.DEAL_OR_NO_DEAL]) == 12

    def test_time_capsule_has_5_prompts(self):
        assert len(QUESTION_BANKS[GameType.TIME_CAPSULE]) == 5

    def test_day_1_games_available_immediately(self):
        day1 = get_unlocked_games(1)
        assert GameType.QALB_QUIZ in day1
        assert GameType.WOULD_YOU_RATHER in day1
        assert GameType.ISLAMIC_TRIVIA in day1

    def test_time_capsule_unlocks_day_21(self):
        assert GameType.TIME_CAPSULE not in get_unlocked_games(20)
        assert GameType.TIME_CAPSULE in get_unlocked_games(21)

    def test_36_questions_unlocks_day_21(self):
        assert GameType.THIRTY_SIX_Q not in get_unlocked_games(20)
        assert GameType.THIRTY_SIX_Q in get_unlocked_games(21)

    def test_all_unlock_days_valid(self):
        for gtype, meta in GAME_REGISTRY.items():
            assert 1 <= meta["unlock_day"] <= 35, f"{gtype}: day {meta['unlock_day']}"

    def test_would_you_rather_is_realtime(self):
        assert GAME_REGISTRY[GameType.WOULD_YOU_RATHER]["mode"] == GameMode.REAL_TIME

    def test_qalb_quiz_is_async(self):
        assert GAME_REGISTRY[GameType.QALB_QUIZ]["mode"] == GameMode.ASYNC_TURN

    def test_time_capsule_is_timer_sealed(self):
        assert GAME_REGISTRY[GameType.TIME_CAPSULE]["mode"] == GameMode.TIMER_SEALED

    def test_arabic_names_present_for_all(self):
        for gtype, meta in GAME_REGISTRY.items():
            assert meta.get("name_ar"), f"{gtype} missing Arabic name"


class TestGameStateHelpers:

    def test_build_initial_state(self):
        a, b  = str(uuid4()), str(uuid4())
        state = build_initial_state(GameType.QALB_QUIZ, a, b)
        assert state["status"]       == GameStatus.IN_PROGRESS
        assert state["current_turn"] == a
        assert state["turn_number"]  == 0
        assert state["turns"]        == []
        assert a in state["scores"]
        assert b in state["scores"]

    def test_time_capsule_initial_state(self):
        state = build_initial_state(GameType.TIME_CAPSULE, str(uuid4()), str(uuid4()))
        assert state["sealed"] is False
        assert state["opens_at"] is None
        assert state["seal_days"] == 30

    def test_next_turn_alternates(self):
        a, b  = str(uuid4()), str(uuid4())
        state = build_initial_state(GameType.QALB_QUIZ, a, b)
        state = next_turn(state, a, b)
        assert state["current_turn"] == b
        assert state["turn_number"]  == 1
        state = next_turn(state, b, a)
        assert state["current_turn"] == a

    def test_game_complete_at_max_turns(self):
        a, b  = str(uuid4()), str(uuid4())
        state = build_initial_state(GameType.QALB_QUIZ, a, b)
        assert not is_game_complete(state, GameType.QALB_QUIZ)
        state["turn_number"] = GAME_REGISTRY[GameType.QALB_QUIZ]["turns"]
        assert is_game_complete(state, GameType.QALB_QUIZ)

    def test_seal_time_capsule(self):
        state  = build_initial_state(GameType.TIME_CAPSULE, str(uuid4()), str(uuid4()))
        sealed = seal_time_capsule(state)
        assert sealed["sealed"] is True
        assert sealed["opens_at"] is not None
        assert sealed["status"]   == GameStatus.SEALED
        opens  = datetime.fromisoformat(sealed["opens_at"])
        delta  = opens - datetime.now(timezone.utc)
        assert 28 <= delta.days <= 31

    def test_capsule_not_open_before_time(self):
        state = seal_time_capsule(
            build_initial_state(GameType.TIME_CAPSULE, str(uuid4()), str(uuid4()))
        )
        assert is_capsule_open(state) is False

    def test_capsule_open_after_time(self):
        state = seal_time_capsule(
            build_initial_state(GameType.TIME_CAPSULE, str(uuid4()), str(uuid4()))
        )
        state["opens_at"] = (datetime.now(timezone.utc) - timedelta(days=1)).isoformat()
        assert is_capsule_open(state) is True

    def test_capsule_not_open_if_not_sealed(self):
        assert is_capsule_open({"sealed": False, "opens_at": None}) is False


class TestGameService:

    def _match(self, sender=None, receiver=None):
        m = MagicMock(spec=Match)
        m.id               = uuid4()
        m.sender_id        = sender   or uuid4()
        m.receiver_id      = receiver or uuid4()
        m.status           = MatchStatus.ACTIVE
        m.became_mutual_at = datetime.now(timezone.utc)
        m.game_states      = {}
        m.memory_timeline  = []
        m.sender_wali_approved   = True
        m.receiver_wali_approved = True
        return m

    @pytest.mark.asyncio
    async def test_start_locked_game_fails(self):
        from app.services.games import start_game
        sender_id = uuid4()
        match     = self._match(sender=sender_id)
        match.became_mutual_at = datetime.now(timezone.utc)  # day 0

        db = AsyncMock()
        res = MagicMock(); res.scalar_one_or_none.return_value = match
        db.execute = AsyncMock(return_value=res); db.flush = AsyncMock()

        with pytest.raises(ValueError, match="unlocks on day"):
            await start_game(db, match.id, sender_id, GameType.TIME_CAPSULE)

    @pytest.mark.asyncio
    async def test_start_unknown_game_fails(self):
        from app.services.games import start_game
        with pytest.raises(ValueError, match="Unknown"):
            await start_game(AsyncMock(), uuid4(), uuid4(), "fake_game")

    @pytest.mark.asyncio
    async def test_submit_empty_answer_fails(self):
        from app.services.games import submit_turn
        with pytest.raises(ValueError, match="empty"):
            await submit_turn(AsyncMock(), uuid4(), uuid4(), GameType.QALB_QUIZ, "")

    @pytest.mark.asyncio
    async def test_submit_wrong_turn_fails(self):
        from app.services.games import submit_turn
        sender_id, receiver_id = uuid4(), uuid4()
        match = self._match(sender=sender_id, receiver=receiver_id)
        state = build_initial_state(GameType.QALB_QUIZ, str(sender_id), str(receiver_id))
        state["current_turn"] = str(receiver_id)
        match.game_states = {GameType.QALB_QUIZ: state}

        db = AsyncMock()
        res = MagicMock(); res.scalar_one_or_none.return_value = match
        db.execute = AsyncMock(return_value=res)
        db.flush = AsyncMock(); db.add = MagicMock()

        with pytest.raises(ValueError, match="not your turn"):
            await submit_turn(db, match.id, sender_id, GameType.QALB_QUIZ, "My answer is this one")

    def test_match_day_calculation(self):
        from app.services.games import _match_day
        m = MagicMock(spec=Match)
        m.became_mutual_at = datetime.now(timezone.utc) - timedelta(days=7)
        assert _match_day(m) == 7

    def test_match_day_zero_when_none(self):
        from app.services.games import _match_day
        m = MagicMock(spec=Match)
        m.became_mutual_at = None
        assert _match_day(m) == 0


class TestGamesRouter:

    def test_router_loaded(self):
        from app.routers.games import router
        assert len(router.routes) >= 8

    def test_turn_request_rejects_empty(self):
        from app.routers.games import SubmitTurnRequest
        from pydantic import ValidationError
        with pytest.raises(ValidationError):
            SubmitTurnRequest(answer="")

    def test_realtime_request_valid(self):
        from app.routers.games import RealtimeAnswerRequest
        req = RealtimeAnswerRequest(question_id="it001", answer="114")
        assert req.question_id == "it001"
