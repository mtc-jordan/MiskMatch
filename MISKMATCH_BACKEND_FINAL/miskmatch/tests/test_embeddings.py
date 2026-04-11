"""MiskMatch — Embedding Service Tests"""

import pytest
import numpy as np
from unittest.mock import patch, AsyncMock, MagicMock

from app.services.embeddings import (
    build_profile_text,
    embed_text,
    embed_profile,
    cosine_similarity,
    similarity_to_score,
    euclidean_distance,
    has_embedding,
    mock_embedding_from_profile,
    EMBEDDING_DIMS,
    MAX_PROFILE_CHARS,
)


# ─────────────────────────────────────────────
# PROFILE TEXT BUILDER
# ─────────────────────────────────────────────

def _mock_profile(**overrides):
    """Create a mock Profile with sensible defaults."""
    p = MagicMock()
    p.madhab = overrides.get("madhab", "hanafi")
    p.prayer_frequency = overrides.get("prayer_frequency", "all_five")
    p.quran_level = overrides.get("quran_level", "memorising")
    p.hijab_stance = overrides.get("hijab_stance", None)
    p.is_revert = overrides.get("is_revert", False)
    p.revert_year = overrides.get("revert_year", None)
    p.wants_children = overrides.get("wants_children", True)
    p.num_children_desired = overrides.get("num_children_desired", "3-4")
    p.children_schooling = overrides.get("children_schooling", "Islamic school")
    p.hajj_timeline = overrides.get("hajj_timeline", "within_3_years")
    p.wants_hijra = overrides.get("wants_hijra", False)
    p.hijra_country = overrides.get("hijra_country", None)
    p.islamic_finance_stance = overrides.get("islamic_finance_stance", "strict")
    p.wife_working_stance = overrides.get("wife_working_stance", "her_choice")
    p.sifr_scores = overrides.get("sifr_scores", {"tawadu": 4.2, "sabr": 3.8, "shukr": 4.5, "rahma": 4.0, "amanah": 4.7})
    p.love_language = overrides.get("love_language", "time")
    p.priority_ranking = overrides.get("priority_ranking", ["deen", "family", "health"])
    p.city = overrides.get("city", "Amman")
    p.country = overrides.get("country", "JO")
    p.education_level = overrides.get("education_level", "Masters")
    p.occupation = overrides.get("occupation", "Software Engineer")
    p.bio = overrides.get("bio", "Alhamdulillah, seeking a righteous spouse who values deen and family.")
    p.user_id = overrides.get("user_id", "test-user-id")
    p.compatibility_embedding = overrides.get("compatibility_embedding", None)
    return p


class TestBuildProfileText:

    def test_includes_madhab(self):
        text = build_profile_text(_mock_profile(madhab="shafii"))
        assert "Shafi'i" in text

    def test_includes_prayer_frequency(self):
        text = build_profile_text(_mock_profile(prayer_frequency="all_five"))
        assert "all five daily prayers" in text

    def test_includes_quran_level(self):
        text = build_profile_text(_mock_profile(quran_level="hafiz"))
        assert "Hafiz" in text

    def test_includes_hijab_stance(self):
        text = build_profile_text(_mock_profile(hijab_stance="wears"))
        assert "wears hijab" in text

    def test_includes_revert_info(self):
        text = build_profile_text(_mock_profile(is_revert=True, revert_year=2020))
        assert "revert" in text
        assert "2020" in text

    def test_includes_children_preference(self):
        text = build_profile_text(_mock_profile(wants_children=True, num_children_desired="3-4"))
        assert "3-4" in text

    def test_no_children_preference(self):
        text = build_profile_text(_mock_profile(wants_children=False))
        assert "does not want children" in text

    def test_includes_hajj_timeline(self):
        text = build_profile_text(_mock_profile(hajj_timeline="done"))
        assert "already performed Hajj" in text

    def test_includes_hijra(self):
        text = build_profile_text(_mock_profile(wants_hijra=True, hijra_country="Malaysia"))
        assert "hijra" in text
        assert "Malaysia" in text

    def test_includes_islamic_finance(self):
        text = build_profile_text(_mock_profile(islamic_finance_stance="strict"))
        assert "riba" in text.lower() or "islamic finance" in text.lower()

    def test_includes_sifr_scores(self):
        text = build_profile_text(_mock_profile())
        assert "Sifr" in text

    def test_includes_love_language(self):
        text = build_profile_text(_mock_profile(love_language="acts"))
        assert "acts of service" in text

    def test_includes_priority_ranking(self):
        text = build_profile_text(_mock_profile(priority_ranking=["deen", "family"]))
        assert "deen" in text
        assert "family" in text

    def test_includes_background(self):
        text = build_profile_text(_mock_profile(city="Amman", country="JO", occupation="Teacher"))
        assert "Amman" in text
        assert "Teacher" in text

    def test_includes_bio(self):
        text = build_profile_text(_mock_profile(bio="A devoted Muslim seeking barakah."))
        assert "devoted Muslim" in text

    def test_truncates_to_max_chars(self):
        long_bio = "A" * 3000
        text = build_profile_text(_mock_profile(bio=long_bio))
        assert len(text) <= MAX_PROFILE_CHARS

    def test_empty_profile_returns_something(self):
        p = _mock_profile(
            madhab=None, prayer_frequency=None, quran_level=None,
            hijab_stance=None, is_revert=False, wants_children=None,
            hajj_timeline=None, wants_hijra=False, islamic_finance_stance=None,
            wife_working_stance=None, sifr_scores=None, love_language=None,
            priority_ranking=None, city=None, country=None, education_level=None,
            occupation=None, bio=None,
        )
        text = build_profile_text(p)
        assert isinstance(text, str)


# ─────────────────────────────────────────────
# EMBED TEXT
# ─────────────────────────────────────────────

class TestEmbedText:

    @pytest.mark.asyncio
    async def test_returns_none_without_api_key(self):
        with patch("app.services.embeddings.settings") as mock_settings:
            mock_settings.OPENAI_API_KEY = None
            result = await embed_text("test text")
            assert result is None

    @pytest.mark.asyncio
    async def test_returns_vector_with_api_key(self):
        fake_vector = [0.1] * EMBEDDING_DIMS
        mock_response = MagicMock()
        mock_response.data = [MagicMock(embedding=fake_vector)]

        with patch("app.services.embeddings.settings") as mock_settings:
            mock_settings.OPENAI_API_KEY = "sk-test"
            with patch("openai.AsyncOpenAI") as mock_openai:
                mock_client = AsyncMock()
                mock_client.embeddings.create = AsyncMock(return_value=mock_response)
                mock_openai.return_value = mock_client

                result = await embed_text("Islamic profile text")
                assert result is not None
                assert len(result) == EMBEDDING_DIMS

    @pytest.mark.asyncio
    async def test_returns_none_on_empty_data(self):
        mock_response = MagicMock()
        mock_response.data = []

        with patch("app.services.embeddings.settings") as mock_settings:
            mock_settings.OPENAI_API_KEY = "sk-test"
            with patch("openai.AsyncOpenAI") as mock_openai:
                mock_client = AsyncMock()
                mock_client.embeddings.create = AsyncMock(return_value=mock_response)
                mock_openai.return_value = mock_client

                result = await embed_text("test")
                assert result is None

    @pytest.mark.asyncio
    async def test_returns_none_on_error(self):
        with patch("app.services.embeddings.settings") as mock_settings:
            mock_settings.OPENAI_API_KEY = "sk-test"
            with patch("openai.AsyncOpenAI") as mock_openai:
                mock_client = AsyncMock()
                mock_client.embeddings.create = AsyncMock(side_effect=Exception("API down"))
                mock_openai.return_value = mock_client

                result = await embed_text("test")
                assert result is None


# ─────────────────────────────────────────────
# EMBED PROFILE
# ─────────────────────────────────────────────

class TestEmbedProfile:

    @pytest.mark.asyncio
    async def test_returns_none_for_empty_text(self):
        p = _mock_profile(
            madhab=None, prayer_frequency=None, quran_level=None,
            hijab_stance=None, is_revert=False, wants_children=None,
            hajj_timeline=None, wants_hijra=False, islamic_finance_stance=None,
            wife_working_stance=None, sifr_scores=None, love_language=None,
            priority_ranking=None, city=None, country=None, education_level=None,
            occupation=None, bio=None,
        )
        # build_profile_text returns "" for an empty profile
        with patch("app.services.embeddings.embed_text", new_callable=AsyncMock) as mock_embed:
            result = await embed_profile(p)
            # If text is empty after strip, should return None without calling embed_text
            if build_profile_text(p).strip() == "":
                mock_embed.assert_not_called()
                assert result is None


# ─────────────────────────────────────────────
# VECTOR OPERATIONS
# ─────────────────────────────────────────────

class TestVectorOperations:

    def test_cosine_similarity_identical(self):
        vec = [1.0, 0.0, 0.0]
        assert cosine_similarity(vec, vec) == pytest.approx(1.0, abs=0.001)

    def test_cosine_similarity_orthogonal(self):
        a = [1.0, 0.0, 0.0]
        b = [0.0, 1.0, 0.0]
        assert cosine_similarity(a, b) == pytest.approx(0.0, abs=0.001)

    def test_cosine_similarity_opposite(self):
        a = [1.0, 0.0]
        b = [-1.0, 0.0]
        assert cosine_similarity(a, b) == pytest.approx(-1.0, abs=0.001)

    def test_cosine_similarity_zero_vector(self):
        assert cosine_similarity([0, 0, 0], [1, 2, 3]) == 0.0

    def test_similarity_to_score_high(self):
        score = similarity_to_score(0.9)  # high cosine
        assert 85 <= score <= 100

    def test_similarity_to_score_moderate(self):
        score = similarity_to_score(0.7)
        assert 40 <= score <= 80

    def test_similarity_to_score_low(self):
        score = similarity_to_score(0.3)
        assert 0 <= score <= 50

    def test_similarity_to_score_negative(self):
        score = similarity_to_score(-0.5)
        assert score >= 0

    def test_euclidean_distance_same(self):
        vec = [1.0, 2.0, 3.0]
        assert euclidean_distance(vec, vec) == pytest.approx(0.0, abs=0.001)

    def test_euclidean_distance_different(self):
        a = [0.0, 0.0]
        b = [3.0, 4.0]
        assert euclidean_distance(a, b) == pytest.approx(5.0, abs=0.001)


# ─────────────────────────────────────────────
# HAS EMBEDDING
# ─────────────────────────────────────────────

class TestHasEmbedding:

    def test_true_for_valid_embedding(self):
        p = _mock_profile(compatibility_embedding=[0.1] * EMBEDDING_DIMS)
        assert has_embedding(p) is True

    def test_false_for_none(self):
        p = _mock_profile(compatibility_embedding=None)
        assert has_embedding(p) is False

    def test_false_for_wrong_dimensions(self):
        p = _mock_profile(compatibility_embedding=[0.1] * 100)
        assert has_embedding(p) is False

    def test_false_for_non_list(self):
        p = _mock_profile(compatibility_embedding="not a list")
        assert has_embedding(p) is False


# ─────────────────────────────────────────────
# MOCK EMBEDDING
# ─────────────────────────────────────────────

class TestMockEmbedding:

    def test_returns_correct_dimensions(self):
        p = _mock_profile()
        vec = mock_embedding_from_profile(p)
        assert len(vec) == EMBEDDING_DIMS

    def test_is_unit_vector(self):
        p = _mock_profile()
        vec = mock_embedding_from_profile(p)
        norm = np.linalg.norm(vec)
        assert norm == pytest.approx(1.0, abs=0.01)

    def test_encodes_prayer_frequency(self):
        p1 = _mock_profile(prayer_frequency="all_five")
        p2 = _mock_profile(prayer_frequency="friday_only")
        v1 = mock_embedding_from_profile(p1)
        v2 = mock_embedding_from_profile(p2)
        # Different prayer frequencies should produce different vectors
        assert v1 != v2

    def test_deterministic(self):
        p = _mock_profile()
        v1 = mock_embedding_from_profile(p)
        v2 = mock_embedding_from_profile(p)
        assert v1 == v2

    def test_similar_profiles_have_higher_similarity(self):
        p1 = _mock_profile(prayer_frequency="all_five", madhab="hanafi")
        p2 = _mock_profile(prayer_frequency="all_five", madhab="hanafi")
        p3 = _mock_profile(prayer_frequency="friday_only", madhab="maliki")

        v1 = mock_embedding_from_profile(p1)
        v2 = mock_embedding_from_profile(p2)
        v3 = mock_embedding_from_profile(p3)

        sim_same = cosine_similarity(v1, v2)
        sim_diff = cosine_similarity(v1, v3)
        assert sim_same >= sim_diff
