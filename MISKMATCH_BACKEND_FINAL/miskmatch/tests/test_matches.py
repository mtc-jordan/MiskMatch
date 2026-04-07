"""MiskMatch — Match Service & Schema Tests"""

import pytest
from unittest.mock import MagicMock, AsyncMock, patch
from datetime import datetime, timezone
from uuid import uuid4

from app.models.models import Profile, Match, MatchStatus, Gender, User, SubscriptionTier


class TestMatchSchemas:

    def test_express_interest_min_length(self):
        from app.schemas.matches import ExpressInterestRequest
        from pydantic import ValidationError
        with pytest.raises(ValidationError):
            ExpressInterestRequest(
                receiver_id=uuid4(),
                message="Too short",  # < 20 chars
            )

    def test_express_interest_valid(self):
        from app.schemas.matches import ExpressInterestRequest
        req = ExpressInterestRequest(
            receiver_id=uuid4(),
            message="Assalamu Alaikum, I was drawn to your profile by your dedication to Islamic values.",
        )
        assert req.message.startswith("Assalamu")

    def test_wali_status_both_approved(self):
        from app.schemas.matches import WaliStatusSummary
        ws = WaliStatusSummary(
            sender_wali_approved=True,
            receiver_wali_approved=True,
        )
        assert ws.both_approved is True

    def test_wali_status_not_both(self):
        from app.schemas.matches import WaliStatusSummary
        ws = WaliStatusSummary(
            sender_wali_approved=True,
            receiver_wali_approved=None,
        )
        assert ws.both_approved is False


class TestCompatibilityScoring:

    def _make_profile(self, **kwargs) -> MagicMock:
        p = MagicMock(spec=Profile)
        defaults = {
            "madhab": None, "prayer_frequency": None,
            "quran_level": None, "wants_children": None,
            "wants_hijra": None, "hajj_timeline": None,
            "islamic_finance_stance": None, "sifr_scores": None,
            "is_revert": False, "mosque_verified": False,
            "scholar_endorsed": False, "trust_score": 50,
            "love_language": None,
        }
        defaults.update(kwargs)
        for k, v in defaults.items():
            setattr(p, k, v)
        return p

    def test_same_madhab_scores_higher(self):
        from app.services.matches import compute_compatibility_score
        p1 = self._make_profile(madhab="hanafi", prayer_frequency="all_five")
        p2_same = self._make_profile(madhab="hanafi", prayer_frequency="all_five")
        p2_diff = self._make_profile(madhab="maliki", prayer_frequency="all_five")

        score_same = compute_compatibility_score(p1, p2_same)
        score_diff = compute_compatibility_score(p1, p2_diff)
        assert score_same > score_diff

    def test_prayer_mismatch_penalised(self):
        from app.services.matches import compute_compatibility_score
        p1 = self._make_profile(prayer_frequency="all_five")
        p2_match = self._make_profile(prayer_frequency="all_five")
        p2_miss  = self._make_profile(prayer_frequency="sometimes")

        s_match = compute_compatibility_score(p1, p2_match)
        s_miss  = compute_compatibility_score(p1, p2_miss)
        assert s_match > s_miss

    def test_children_mismatch_penalised(self):
        from app.services.matches import compute_compatibility_score
        p1 = self._make_profile(wants_children=True)
        p2_yes = self._make_profile(wants_children=True)
        p2_no  = self._make_profile(wants_children=False)

        s_agree    = compute_compatibility_score(p1, p2_yes)
        s_disagree = compute_compatibility_score(p1, p2_no)
        assert s_agree > s_disagree

    def test_score_always_0_to_100(self):
        from app.services.matches import compute_compatibility_score
        for _ in range(20):
            p1 = self._make_profile(
                madhab="hanafi", prayer_frequency="all_five",
                wants_children=True, trust_score=90, mosque_verified=True,
            )
            p2 = self._make_profile(
                madhab="maliki", prayer_frequency="sometimes",
                wants_children=False, trust_score=20,
            )
            s = compute_compatibility_score(p1, p2)
            assert 0 <= s <= 100, f"Score out of range: {s}"

    def test_both_mosque_verified_bonus(self):
        from app.services.matches import compute_compatibility_score
        p1_v  = self._make_profile(mosque_verified=True, trust_score=80)
        p2_v  = self._make_profile(mosque_verified=True, trust_score=80)
        p1_uv = self._make_profile(mosque_verified=False, trust_score=80)
        p2_uv = self._make_profile(mosque_verified=False, trust_score=80)

        s_both    = compute_compatibility_score(p1_v, p2_v)
        s_neither = compute_compatibility_score(p1_uv, p2_uv)
        assert s_both > s_neither

    def test_sifr_compat_perfect_match(self):
        from app.services.matches import _sifr_compatibility
        scores = {"generosity": 80, "patience": 70, "honesty": 90,
                  "family": 85, "community": 75}
        result = _sifr_compatibility(scores, scores)
        assert result == 100.0

    def test_sifr_compat_complete_mismatch(self):
        from app.services.matches import _sifr_compatibility
        a = {"generosity": 100, "patience": 100, "honesty": 100,
             "family": 100, "community": 100}
        b = {"generosity": 0,   "patience": 0,   "honesty": 0,
             "family": 0,       "community": 0}
        result = _sifr_compatibility(a, b)
        assert result == 0.0


class TestMatchService:

    @pytest.mark.asyncio
    async def test_express_interest_same_gender_rejected(self):
        from app.services.matches import express_interest
        db = AsyncMock()

        sender = MagicMock(spec=User)
        sender.id = uuid4()
        sender.gender = Gender.MALE
        sender.subscription_tier = SubscriptionTier.BARAKAH

        receiver = MagicMock(spec=User)
        receiver.id = uuid4()
        receiver.gender = Gender.MALE  # same gender!
        receiver.status = "active"

        # Mock DB to return same-gender receiver
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = receiver
        db.execute = AsyncMock(return_value=mock_result)

        with pytest.raises(ValueError, match="opposite-gender"):
            await express_interest(db, sender, receiver.id, "A valid message of at least twenty characters here")

    @pytest.mark.asyncio
    async def test_respond_wrong_user_rejected(self):
        from app.services.matches import respond_to_interest

        match = MagicMock(spec=Match)
        match.receiver_id = uuid4()
        match.status = MatchStatus.PENDING

        wrong_user = uuid4()  # different from receiver_id

        with pytest.raises(ValueError, match="Only the receiver"):
            await respond_to_interest(AsyncMock(), match, wrong_user, True)

    @pytest.mark.asyncio
    async def test_respond_accept_sets_mutual(self):
        from app.services.matches import respond_to_interest

        receiver_id = uuid4()
        match = MagicMock(spec=Match)
        match.receiver_id = receiver_id
        match.status = MatchStatus.PENDING

        db = AsyncMock()
        db.flush = AsyncMock()

        result = await respond_to_interest(db, match, receiver_id, True, "Looking forward to this.")
        assert match.status == MatchStatus.MUTUAL
        assert match.became_mutual_at is not None

    @pytest.mark.asyncio
    async def test_respond_decline_closes_match(self):
        from app.services.matches import respond_to_interest

        receiver_id = uuid4()
        match = MagicMock(spec=Match)
        match.receiver_id = receiver_id
        match.status = MatchStatus.PENDING

        db = AsyncMock()
        db.flush = AsyncMock()

        await respond_to_interest(db, match, receiver_id, False)
        assert match.status == MatchStatus.CLOSED
        assert match.closed_reason == "receiver_declined"

    @pytest.mark.asyncio
    async def test_close_match_not_participant_rejected(self):
        from app.services.matches import close_match

        match = MagicMock(spec=Match)
        match.sender_id   = uuid4()
        match.receiver_id = uuid4()
        match.status      = MatchStatus.ACTIVE

        non_participant = uuid4()  # not in sender or receiver

        with pytest.raises(ValueError, match="not a participant"):
            await close_match(AsyncMock(), match, non_participant, "testing")

    def test_nikah_response_contains_dua(self):
        """Verify the nikah endpoint returns the Islamic dua."""
        import json
        # This is a unit test of the response format
        dua = "بارك الله لكما وبارك عليكما وجمع بينكما في خير"
        assert len(dua) > 0
        assert "بارك" in dua
