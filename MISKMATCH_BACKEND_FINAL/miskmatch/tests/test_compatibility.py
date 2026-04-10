"""MiskMatch — AI Deen Compatibility Engine Tests"""

import pytest
import math
from datetime import datetime, timezone, timedelta
from unittest.mock import AsyncMock, MagicMock, patch
from uuid import uuid4

import numpy as np

from app.services.embeddings import (
    build_profile_text, cosine_similarity, similarity_to_score,
    has_embedding, mock_embedding_from_profile, EMBEDDING_DIMS,
)
from app.services.compatibility import (
    compute_hybrid_score, explain_compatibility,
    _rule_score, _age_range_compatible, DEALBREAKER_THRESHOLD,
)
from app.models.models import Profile, Gender


# ─────────────────────────────────────────────
# PROFILE FACTORY
# ─────────────────────────────────────────────

def make_profile(**kwargs) -> Profile:
    p = MagicMock(spec=Profile)
    p.user_id               = uuid4()
    p.first_name            = "Test"
    p.last_name             = "User"
    p.date_of_birth         = datetime(1995, 1, 1, tzinfo=timezone.utc)
    p.city                  = "Amman"
    p.country               = "JO"
    p.madhab                = "hanbali"
    p.prayer_frequency      = "all_five"
    p.hijab_stance          = "wears"
    p.quran_level           = "recites_tajweed"
    p.is_revert             = False
    p.revert_year           = None
    p.wants_children        = True
    p.num_children_desired  = "2-3"
    p.hajj_timeline         = "within_5_years"
    p.wants_hijra           = False
    p.hijra_country         = None
    p.islamic_finance_stance= "prefers"
    p.wife_working_stance   = "her_choice"
    p.sifr_scores           = {"tawadu": 4.0, "sabr": 3.5, "shukr": 4.2, "rahma": 4.5, "amanah": 4.0}
    p.love_language         = "acts"
    p.priority_ranking      = ["Deen", "Family", "Health"]
    p.bio                   = "A practicing Muslim seeking a righteous partner to build a home of barakah."
    p.trust_score           = 75
    p.mosque_verified       = True
    p.scholar_endorsed      = False
    p.education_level       = "bachelors"
    p.occupation            = "Engineer"
    p.min_age               = 22
    p.max_age               = 38
    p.compatibility_embedding = None
    for k, v in kwargs.items():
        setattr(p, k, v)
    return p


# ─────────────────────────────────────────────
# PROFILE TEXT BUILDER
# ─────────────────────────────────────────────

class TestProfileTextBuilder:

    def test_builds_non_empty_text(self):
        profile = make_profile()
        text = build_profile_text(profile)
        assert len(text) > 50

    def test_includes_prayer_frequency(self):
        profile = make_profile(prayer_frequency="all_five")
        text = build_profile_text(profile)
        assert "five" in text.lower() or "prayer" in text.lower()

    def test_includes_madhab(self):
        profile = make_profile(madhab="hanbali")
        text = build_profile_text(profile)
        assert "Hanbali" in text

    def test_includes_quran_hafiz(self):
        profile = make_profile(quran_level="hafiz")
        text = build_profile_text(profile)
        assert "Hafiz" in text or "hafiz" in text.lower()

    def test_includes_hijab_stance(self):
        profile = make_profile(hijab_stance="wears")
        text = build_profile_text(profile)
        assert "hijab" in text.lower()

    def test_revert_included(self):
        profile = make_profile(is_revert=True, revert_year=2018)
        text = build_profile_text(profile)
        assert "revert" in text.lower()
        assert "2018" in text

    def test_life_goals_included(self):
        profile = make_profile(
            wants_children=True, num_children_desired="3-4",
            hajj_timeline="within_3_years"
        )
        text = build_profile_text(profile)
        assert "children" in text.lower()
        assert "Hajj" in text or "hajj" in text.lower()

    def test_sifr_scores_included(self):
        profile = make_profile(
            sifr_scores={"tawadu": 4.8, "sabr": 4.5, "shukr": 4.0, "rahma": 3.5, "amanah": 4.2}
        )
        text = build_profile_text(profile)
        assert "humility" in text.lower() or "patience" in text.lower()

    def test_bio_included(self):
        profile = make_profile(bio="I love hiking and reading Seerah books on weekends.")
        text = build_profile_text(profile)
        assert "hiking" in text or "Seerah" in text

    def test_no_bio_still_works(self):
        profile = make_profile(bio=None)
        text = build_profile_text(profile)
        assert len(text) > 20

    def test_max_length_respected(self):
        profile = make_profile(bio="x" * 3000)
        text = build_profile_text(profile)
        assert len(text) <= 2000

    def test_wants_hijra_included(self):
        profile = make_profile(wants_hijra=True, hijra_country="Malaysia")
        text = build_profile_text(profile)
        assert "hijra" in text.lower()
        assert "Malaysia" in text

    def test_islamic_finance_strict(self):
        profile = make_profile(islamic_finance_stance="strict")
        text = build_profile_text(profile)
        assert "interest" in text.lower() or "riba" in text.lower()

    def test_love_language_included(self):
        profile = make_profile(love_language="acts")
        text = build_profile_text(profile)
        assert "service" in text.lower() or "love" in text.lower()

    def test_priority_ranking_included(self):
        profile = make_profile(priority_ranking=["Deen", "Family", "Career"])
        text = build_profile_text(profile)
        assert "Deen" in text or "Family" in text


# ─────────────────────────────────────────────
# VECTOR OPERATIONS
# ─────────────────────────────────────────────

class TestVectorOps:

    def test_identical_vectors_similarity_1(self):
        vec = [1.0, 0.0, 0.0, 0.5]
        assert abs(cosine_similarity(vec, vec) - 1.0) < 1e-5

    def test_orthogonal_vectors_similarity_0(self):
        a = [1.0, 0.0]
        b = [0.0, 1.0]
        assert abs(cosine_similarity(a, b)) < 1e-5

    def test_opposite_vectors_similarity_minus1(self):
        a = [1.0, 0.0]
        b = [-1.0, 0.0]
        assert abs(cosine_similarity(a, b) + 1.0) < 1e-5

    def test_zero_vector_returns_0(self):
        a = [0.0, 0.0, 0.0]
        b = [1.0, 2.0, 3.0]
        assert cosine_similarity(a, b) == 0.0

    def test_similarity_to_score_high(self):
        score = similarity_to_score(0.85)
        assert score > 80

    def test_similarity_to_score_low(self):
        score = similarity_to_score(0.3)
        assert score < 40

    def test_similarity_to_score_perfect(self):
        score = similarity_to_score(1.0)
        assert score >= 95

    def test_similarity_to_score_range(self):
        for sim in [-1.0, -0.5, 0.0, 0.5, 0.7, 0.9, 1.0]:
            score = similarity_to_score(sim)
            assert 0 <= score <= 100, f"sim={sim} → score={score} out of range"

    def test_has_embedding_false_when_none(self):
        p = make_profile(compatibility_embedding=None)
        assert has_embedding(p) is False

    def test_has_embedding_false_wrong_dims(self):
        p = make_profile(compatibility_embedding=[0.1, 0.2, 0.3])
        assert has_embedding(p) is False

    def test_has_embedding_true_correct_dims(self):
        p = make_profile(compatibility_embedding=[0.0] * EMBEDDING_DIMS)
        assert has_embedding(p) is True

    def test_mock_embedding_correct_dims(self):
        p = make_profile()
        vec = mock_embedding_from_profile(p)
        assert len(vec) == EMBEDDING_DIMS

    def test_mock_embedding_unit_vector(self):
        p = make_profile()
        vec = mock_embedding_from_profile(p)
        norm = math.sqrt(sum(x*x for x in vec))
        assert abs(norm - 1.0) < 1e-5 or norm == 0.0  # either unit or zero

    def test_mock_embedding_different_profiles_differ(self):
        p1 = make_profile(prayer_frequency="all_five", madhab="hanbali")
        p2 = make_profile(prayer_frequency="friday_only", madhab="hanafi")
        v1 = mock_embedding_from_profile(p1)
        v2 = mock_embedding_from_profile(p2)
        # They should NOT be identical
        assert v1 != v2


# ─────────────────────────────────────────────
# RULE ENGINE
# ─────────────────────────────────────────────

class TestRuleEngine:

    def test_children_mismatch_is_dealbreaker(self):
        a = make_profile(wants_children=True)
        b = make_profile(wants_children=False)
        score, breakdown, is_db, reason = _rule_score(a, b)
        assert is_db is True
        assert "children" in reason.lower()
        assert score == 0.0

    def test_perfect_alignment_scores_high(self):
        a = make_profile(
            prayer_frequency="all_five", madhab="hanbali",
            quran_level="hafiz", wants_children=True,
            hajj_timeline="within_5_years", trust_score=90,
            mosque_verified=True,
        )
        b = make_profile(
            prayer_frequency="all_five", madhab="hanbali",
            quran_level="hafiz", wants_children=True,
            hajj_timeline="within_5_years", trust_score=88,
            mosque_verified=True,
        )
        score, breakdown, is_db, _ = _rule_score(a, b)
        assert is_db is False
        assert score >= 80

    def test_prayer_mismatch_penalises(self):
        a = make_profile(prayer_frequency="all_five")
        b = make_profile(prayer_frequency="sometimes")
        score_a, _, _, _ = _rule_score(a, b)

        c = make_profile(prayer_frequency="all_five")
        d = make_profile(prayer_frequency="all_five")
        score_b, _, _, _ = _rule_score(c, d)

        assert score_b > score_a

    def test_extreme_prayer_mismatch_is_dealbreaker(self):
        a = make_profile(prayer_frequency="all_five")
        b = make_profile(prayer_frequency="friday_only")
        score, _, is_db, _ = _rule_score(a, b)
        assert is_db is True  # 3+ steps apart = dealbreaker

    def test_same_madhab_bonus(self):
        # Use partial profiles so we don't hit the 100-point cap
        a = make_profile(madhab="shafii", wants_children=True,
                         mosque_verified=False, scholar_endorsed=False,
                         trust_score=50, quran_level=None, hajj_timeline=None)
        b = make_profile(madhab="shafii", wants_children=True,
                         mosque_verified=False, scholar_endorsed=False,
                         trust_score=50, quran_level=None, hajj_timeline=None)
        c = make_profile(madhab="hanafi", wants_children=True,
                         mosque_verified=False, scholar_endorsed=False,
                         trust_score=50, quran_level=None, hajj_timeline=None)

        score_same, _, _, _ = _rule_score(a, b)
        score_diff, _, _, _ = _rule_score(a, c)
        assert score_same > score_diff

    def test_mosque_verified_both_gives_bonus(self):
        # Strip other bonuses to isolate the mosque bonus
        base = dict(wants_children=True, scholar_endorsed=False,
                    trust_score=50, quran_level=None, hajj_timeline=None,
                    prayer_frequency="most", madhab=None)
        a = make_profile(mosque_verified=True,  **base)
        b = make_profile(mosque_verified=True,  **base)
        c = make_profile(mosque_verified=False, **base)

        score_both, _, _, _ = _rule_score(a, b)
        score_one, _, _, _  = _rule_score(a, c)
        assert score_both > score_one

    def test_score_capped_at_100(self):
        a = make_profile(
            prayer_frequency="all_five", madhab="hanbali", quran_level="hafiz",
            wants_children=True, hajj_timeline="within_5_years",
            mosque_verified=True, scholar_endorsed=True, trust_score=100,
        )
        score, _, _, _ = _rule_score(a, a)
        assert score <= 100

    def test_score_never_negative(self):
        a = make_profile(prayer_frequency="working_on", wants_children=True, trust_score=10)
        b = make_profile(prayer_frequency="most", wants_children=True, trust_score=90)
        score, _, _, _ = _rule_score(a, b)
        assert score >= 0


# ─────────────────────────────────────────────
# HYBRID SCORING
# ─────────────────────────────────────────────

class TestHybridScoring:

    def test_dealbreaker_returns_zero(self):
        a = make_profile(wants_children=True)
        b = make_profile(wants_children=False)
        result = compute_hybrid_score(a, b)
        assert result.final_score == 0.0
        assert result.dealbreaker is True

    def test_high_alignment_scores_well(self):
        a = make_profile(prayer_frequency="all_five", madhab="hanbali", wants_children=True)
        b = make_profile(prayer_frequency="all_five", madhab="hanbali", wants_children=True)
        result = compute_hybrid_score(a, b)
        assert result.final_score >= 50  # always passes with good alignment

    def test_result_has_all_fields(self):
        a = make_profile(wants_children=True)
        b = make_profile(wants_children=True)
        result = compute_hybrid_score(a, b)
        assert hasattr(result, "final_score")
        assert hasattr(result, "rule_score")
        assert hasattr(result, "ai_score")
        assert hasattr(result, "breakdown")
        assert hasattr(result, "dealbreaker")

    def test_to_dict_serialisable(self):
        a = make_profile(wants_children=True)
        b = make_profile(wants_children=True)
        result = compute_hybrid_score(a, b)
        d = result.to_dict()
        import json
        json.dumps(d)  # must not raise

    def test_real_embeddings_flag_false_without_vectors(self):
        a = make_profile(compatibility_embedding=None)
        b = make_profile(compatibility_embedding=None)
        result = compute_hybrid_score(a, b)
        assert result.has_ai is False   # no real embeddings

    def test_real_embeddings_flag_true_with_vectors(self):
        vec = [0.1] * EMBEDDING_DIMS
        a = make_profile(compatibility_embedding=vec)
        b = make_profile(compatibility_embedding=vec)
        result = compute_hybrid_score(a, b)
        assert result.has_ai is True

    def test_ai_boosts_similar_profiles(self):
        """Profiles with same embedding should score higher than different ones."""
        vec_a = [1.0 if i == 0 else 0.0 for i in range(EMBEDDING_DIMS)]
        vec_b = [1.0 if i == 0 else 0.0 for i in range(EMBEDDING_DIMS)]  # same
        vec_c = [1.0 if i == 1 else 0.0 for i in range(EMBEDDING_DIMS)]  # orthogonal

        a = make_profile(wants_children=True, compatibility_embedding=vec_a)
        b = make_profile(wants_children=True, compatibility_embedding=vec_b)
        c = make_profile(wants_children=True, compatibility_embedding=vec_c)

        result_similar  = compute_hybrid_score(a, b)
        result_different = compute_hybrid_score(a, c)

        assert result_similar.final_score > result_different.final_score


# ─────────────────────────────────────────────
# EXPLAINABILITY
# ─────────────────────────────────────────────

class TestExplainability:

    def test_dealbreaker_explanation(self):
        a = make_profile(wants_children=True)
        b = make_profile(wants_children=False)
        result = compute_hybrid_score(a, b)
        explanation = explain_compatibility(result, "male")
        assert explanation["tier"] == "incompatible"

    def test_exceptional_score_tier(self):
        a = make_profile(
            prayer_frequency="all_five", madhab="hanbali", wants_children=True,
            trust_score=95, mosque_verified=True,
            compatibility_embedding=[1.0] + [0.0] * (EMBEDDING_DIMS - 1),
        )
        b = make_profile(
            prayer_frequency="all_five", madhab="hanbali", wants_children=True,
            trust_score=92, mosque_verified=True,
            compatibility_embedding=[1.0] + [0.0] * (EMBEDDING_DIMS - 1),
        )
        result = compute_hybrid_score(a, b)
        explanation = explain_compatibility(result, "male")
        assert explanation["tier"] in ("exceptional", "strong", "good")

    def test_explanation_has_insights(self):
        a = make_profile(wants_children=True, prayer_frequency="all_five")
        b = make_profile(wants_children=True, prayer_frequency="all_five")
        result = compute_hybrid_score(a, b)
        explanation = explain_compatibility(result, "male")
        assert "insights" in explanation
        assert isinstance(explanation["insights"], list)

    def test_explanation_has_score(self):
        a = make_profile(wants_children=True)
        b = make_profile(wants_children=True)
        result = compute_hybrid_score(a, b)
        explanation = explain_compatibility(result, "female")
        assert "score" in explanation
        assert 0 <= explanation["score"] <= 100


# ─────────────────────────────────────────────
# AGE RANGE
# ─────────────────────────────────────────────

class TestAgeRange:

    def test_compatible_age_range(self):
        seeker    = make_profile(date_of_birth=datetime(1995, 1, 1, tzinfo=timezone.utc),
                                 min_age=22, max_age=38)
        candidate = make_profile(date_of_birth=datetime(1993, 6, 15, tzinfo=timezone.utc),
                                 min_age=25, max_age=40)
        assert _age_range_compatible(seeker, candidate) is True

    def test_candidate_too_young(self):
        seeker    = make_profile(date_of_birth=datetime(1990, 1, 1, tzinfo=timezone.utc),
                                 min_age=30, max_age=45)
        candidate = make_profile(date_of_birth=datetime(2002, 1, 1, tzinfo=timezone.utc),
                                 min_age=20, max_age=35)
        assert _age_range_compatible(seeker, candidate) is False

    def test_no_dob_always_compatible(self):
        seeker    = make_profile(date_of_birth=None, min_age=22, max_age=40)
        candidate = make_profile(date_of_birth=None, min_age=22, max_age=40)
        assert _age_range_compatible(seeker, candidate) is True


# ─────────────────────────────────────────────
# ROUTER
# ─────────────────────────────────────────────

class TestCompatibilityRouter:

    def test_router_loads(self):
        from app.routers.compatibility import router
        assert router.prefix == "/compatibility"

    def test_router_has_all_endpoints(self):
        from app.routers.compatibility import router
        paths = {r.path for r in router.routes if hasattr(r, "path")}
        assert "/compatibility/{match_id}"         in paths
        assert "/compatibility/preview/{candidate_id}" in paths
        assert "/compatibility/embed/me"           in paths
        assert "/compatibility/embed/status/{user_id}" in paths
        assert "/compatibility/admin/reembed"      in paths
        assert "/compatibility/admin/reembed/{task_id}" in paths
        assert "/compatibility/admin/stats"        in paths

    def test_total_route_count(self):
        from app.routers.compatibility import router
        assert len(router.routes) == 7


# ─────────────────────────────────────────────
# HTTP ENDPOINT TESTS
# ─────────────────────────────────────────────

from app.main import app
from app.core.database import get_db
from app.routers.auth import get_current_active_user
from app.models.models import Match, MatchStatus, User, UserRole
from tests.conftest import TEST_USER_ID


@pytest.fixture(autouse=True, scope="class")
def _override_compat_deps(test_user, mock_db):
    async def _fake_get_db():
        yield mock_db

    app.dependency_overrides[get_db] = _fake_get_db
    app.dependency_overrides[get_current_active_user] = lambda: test_user
    yield
    app.dependency_overrides.clear()


class TestCompatibilityHTTP:

    @pytest.mark.asyncio
    async def test_match_compatibility_no_match_404(self, client, mock_db):
        from tests.conftest import mock_db_result
        mock_db.execute = AsyncMock(return_value=mock_db_result(scalar_value=None))
        resp = await client.get(f"/api/v1/compatibility/{uuid4()}")
        assert resp.status_code == 404

    @pytest.mark.asyncio
    async def test_match_compatibility_with_match(self, client, mock_db):
        match_id = uuid4()
        other_id = uuid4()
        match = MagicMock(spec=Match)
        match.id = match_id
        match.sender_id = TEST_USER_ID
        match.receiver_id = other_id
        match.status = MatchStatus.MUTUAL

        sender_profile = make_profile(
            user_id=TEST_USER_ID, wants_children=True,
            prayer_frequency="all_five", madhab="hanbali",
        )
        receiver_profile = make_profile(
            user_id=other_id, wants_children=True,
            prayer_frequency="all_five", madhab="hanbali",
        )

        call_count = [0]
        async def mock_execute(*args, **kwargs):
            call_count[0] += 1
            r = MagicMock()
            if call_count[0] == 1:
                r.scalar_one_or_none.return_value = match
            elif call_count[0] == 2:
                r.scalar_one_or_none.return_value = sender_profile
            else:
                r.scalar_one_or_none.return_value = receiver_profile
            return r
        mock_db.execute = mock_execute

        resp = await client.get(f"/api/v1/compatibility/{match_id}")
        assert resp.status_code == 200
        data = resp.json()
        assert "score" in data
        assert "explanation" in data
        assert data["score"] >= 0

    @pytest.mark.asyncio
    async def test_preview_compatibility_no_profile_422(self, client, mock_db):
        from tests.conftest import mock_db_result
        mock_db.execute = AsyncMock(return_value=mock_db_result(scalar_value=None))
        resp = await client.get(f"/api/v1/compatibility/preview/{uuid4()}")
        assert resp.status_code == 422

    @pytest.mark.asyncio
    async def test_preview_compatibility_success(self, client, mock_db):
        candidate_id = uuid4()
        my_profile = make_profile(
            user_id=TEST_USER_ID, wants_children=True,
            prayer_frequency="all_five",
        )
        cand_profile = make_profile(
            user_id=candidate_id, wants_children=True,
            prayer_frequency="all_five",
        )

        call_count = [0]
        async def mock_execute(*args, **kwargs):
            call_count[0] += 1
            r = MagicMock()
            if call_count[0] == 1:
                r.scalar_one_or_none.return_value = my_profile
            else:
                r.scalar_one_or_none.return_value = cand_profile
            return r
        mock_db.execute = mock_execute

        resp = await client.get(f"/api/v1/compatibility/preview/{candidate_id}")
        assert resp.status_code == 200
        data = resp.json()
        assert "score" in data
        assert "candidate_id" in data

    @pytest.mark.asyncio
    async def test_embed_me_no_profile_422(self, client, mock_db):
        from tests.conftest import mock_db_result
        mock_db.execute = AsyncMock(return_value=mock_db_result(scalar_value=None))
        resp = await client.post("/api/v1/compatibility/embed/me")
        assert resp.status_code == 422

    @pytest.mark.asyncio
    async def test_embed_me_sync_success(self, client, mock_db):
        profile = make_profile(
            user_id=TEST_USER_ID, wants_children=True,
            bio="I love reading and prayer.",
        )
        from tests.conftest import mock_db_result
        mock_db.execute = AsyncMock(return_value=mock_db_result(scalar_value=profile))
        mock_db.commit = AsyncMock()

        with patch("app.routers.compatibility.embed_profile", new_callable=AsyncMock) as mock_embed:
            mock_embed.return_value = [0.1] * EMBEDDING_DIMS
            resp = await client.post("/api/v1/compatibility/embed/me?sync=true")
            assert resp.status_code == 200
            assert resp.json()["status"] == "embedded"

    @pytest.mark.asyncio
    async def test_embed_status_own_profile(self, client, mock_db):
        profile = make_profile(
            user_id=TEST_USER_ID,
            compatibility_embedding=[0.1] * EMBEDDING_DIMS,
        )
        from tests.conftest import mock_db_result
        mock_db.execute = AsyncMock(return_value=mock_db_result(scalar_value=profile))

        resp = await client.get(f"/api/v1/compatibility/embed/status/{TEST_USER_ID}")
        assert resp.status_code == 200
        data = resp.json()
        assert data["has_embedding"] is True
        assert data["embedding_dims"] == EMBEDDING_DIMS

    @pytest.mark.asyncio
    async def test_embed_status_other_user_forbidden(self, client, mock_db):
        other_id = uuid4()
        resp = await client.get(f"/api/v1/compatibility/embed/status/{other_id}")
        assert resp.status_code == 403

    @pytest.mark.asyncio
    async def test_admin_stats_forbidden_for_non_admin(self, client):
        resp = await client.get("/api/v1/compatibility/admin/stats")
        assert resp.status_code == 403

    @pytest.mark.asyncio
    async def test_admin_reembed_forbidden_for_non_admin(self, client):
        resp = await client.post("/api/v1/compatibility/admin/reembed")
        assert resp.status_code == 403
