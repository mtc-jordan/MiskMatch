"""MiskMatch — Moderation Service Tests"""

import pytest
from unittest.mock import patch, AsyncMock, MagicMock

from app.services.moderation import (
    fast_filter,
    ai_moderate,
    moderate_message,
    should_alert_wali,
    ModerationResult,
    HARD_BLOCK_PATTERNS,
    SOFT_FLAG_PATTERNS,
)


# ─────────────────────────────────────────────
# FAST FILTER — HARD BLOCKS
# ─────────────────────────────────────────────

class TestFastFilterHardBlock:

    def test_blocks_explicit_content(self):
        result = fast_filter("send me nude photos please")
        assert result.passed is False
        assert result.category == "explicit_violation"
        assert result.layer == "fast"

    def test_blocks_sexual_content(self):
        result = fast_filter("this is so sexy")
        assert result.passed is False

    def test_blocks_private_meeting(self):
        result = fast_filter("come to my house tonight")
        assert result.passed is False

    def test_blocks_photo_request(self):
        result = fast_filter("send me your photos")
        assert result.passed is False

    def test_blocks_social_media_request(self):
        result = fast_filter("whatsapp me your number")
        assert result.passed is False

    def test_blocks_romantic_boundary(self):
        result = fast_filter("I love you so much")
        assert result.passed is False

    def test_blocks_inappropriate_desire(self):
        result = fast_filter("I want to kiss you")
        assert result.passed is False

    def test_blocks_case_insensitive(self):
        result = fast_filter("SEND ME NUDE PHOTOS")
        assert result.passed is False

    def test_confidence_is_1_for_hard_block(self):
        result = fast_filter("send me your pics")
        assert result.confidence == 1.0


# ─────────────────────────────────────────────
# FAST FILTER — SOFT FLAGS
# ─────────────────────────────────────────────

class TestFastFilterSoftFlag:

    def test_flags_wali_bypass(self):
        result = fast_filter("let's meet without your wali knowing")
        assert result.passed is True
        assert result.category == "soft_flag"
        assert result.confidence == 0.7

    def test_flags_secrecy(self):
        result = fast_filter("keep this secret between us")
        assert result.passed is True
        assert result.category == "soft_flag"

    def test_flags_number_request(self):
        result = fast_filter("can you give me your number?")
        assert result.passed is True
        assert result.category == "soft_flag"


# ─────────────────────────────────────────────
# FAST FILTER — CLEAN MESSAGES
# ─────────────────────────────────────────────

class TestFastFilterClean:

    def test_passes_islamic_greeting(self):
        result = fast_filter("Assalamu Alaikum, how are you?")
        assert result.passed is True
        assert result.reason is None
        assert result.category is None

    def test_passes_deen_discussion(self):
        result = fast_filter("I try to pray all five prayers and read Quran daily")
        assert result.passed is True

    def test_passes_family_discussion(self):
        result = fast_filter("My father is an engineer and my mother is a teacher")
        assert result.passed is True

    def test_passes_marriage_question(self):
        result = fast_filter("How many children would you like to have?")
        assert result.passed is True

    def test_passes_empty_string(self):
        result = fast_filter("")
        assert result.passed is True


# ─────────────────────────────────────────────
# AI MODERATION
# ─────────────────────────────────────────────

class TestAIModeration:

    @pytest.mark.asyncio
    async def test_skips_when_no_api_key(self):
        with patch("app.services.moderation.settings") as mock_settings:
            mock_settings.OPENAI_API_KEY = None
            mock_settings.is_production = False
            result = await ai_moderate("test message")
            assert result.passed is True
            assert result.layer == "bypass"

    @pytest.mark.asyncio
    async def test_blocks_in_production_without_key(self):
        with patch("app.services.moderation.settings") as mock_settings:
            mock_settings.OPENAI_API_KEY = None
            mock_settings.is_production = True
            result = await ai_moderate("test message")
            assert result.passed is False
            assert result.layer == "bypass"

    @pytest.mark.asyncio
    async def test_ai_pass_response(self):
        mock_response = MagicMock()
        mock_response.choices = [MagicMock()]
        mock_response.choices[0].message.content = '{"passed": true, "reason": null, "category": null}'

        with patch("app.services.moderation.settings") as mock_settings:
            mock_settings.OPENAI_API_KEY = "sk-test"
            with patch("openai.AsyncOpenAI") as mock_openai:
                mock_client = AsyncMock()
                mock_client.chat.completions.create = AsyncMock(return_value=mock_response)
                mock_openai.return_value = mock_client

                result = await ai_moderate("Assalamu Alaikum brother")
                assert result.passed is True
                assert result.layer == "ai"

    @pytest.mark.asyncio
    async def test_ai_block_response(self):
        mock_response = MagicMock()
        mock_response.choices = [MagicMock()]
        mock_response.choices[0].message.content = (
            '{"passed": false, "reason": "Romantic boundary violation", "category": "romantic_boundary"}'
        )

        with patch("app.services.moderation.settings") as mock_settings:
            mock_settings.OPENAI_API_KEY = "sk-test"
            with patch("openai.AsyncOpenAI") as mock_openai:
                mock_client = AsyncMock()
                mock_client.chat.completions.create = AsyncMock(return_value=mock_response)
                mock_openai.return_value = mock_client

                result = await ai_moderate("You're the most beautiful person")
                assert result.passed is False
                assert result.category == "romantic_boundary"

    @pytest.mark.asyncio
    async def test_ai_error_passes_through(self):
        with patch("app.services.moderation.settings") as mock_settings:
            mock_settings.OPENAI_API_KEY = "sk-test"
            with patch("openai.AsyncOpenAI") as mock_openai:
                mock_client = AsyncMock()
                mock_client.chat.completions.create = AsyncMock(
                    side_effect=Exception("API error")
                )
                mock_openai.return_value = mock_client

                result = await ai_moderate("test message")
                assert result.passed is True
                assert result.layer == "ai_error"


# ─────────────────────────────────────────────
# FULL PIPELINE
# ─────────────────────────────────────────────

class TestModerationPipeline:

    @pytest.mark.asyncio
    async def test_hard_block_skips_ai(self):
        with patch("app.services.moderation.ai_moderate") as mock_ai:
            result = await moderate_message("send me nude photos")
            assert result.passed is False
            mock_ai.assert_not_called()

    @pytest.mark.asyncio
    async def test_short_message_skips_ai(self):
        with patch("app.services.moderation.ai_moderate") as mock_ai:
            result = await moderate_message("hi")
            assert result.passed is True
            mock_ai.assert_not_called()

    @pytest.mark.asyncio
    async def test_long_clean_message_calls_ai(self):
        with patch("app.services.moderation.ai_moderate", new_callable=AsyncMock) as mock_ai:
            mock_ai.return_value = ModerationResult(passed=True, layer="ai")
            result = await moderate_message("Assalamu Alaikum how is your family doing today")
            assert result.passed is True
            mock_ai.assert_called_once()

    @pytest.mark.asyncio
    async def test_ai_override_blocks_clean_fast_filter(self):
        with patch("app.services.moderation.ai_moderate", new_callable=AsyncMock) as mock_ai:
            mock_ai.return_value = ModerationResult(
                passed=False, reason="Subtle manipulation", category="manipulation", layer="ai",
            )
            result = await moderate_message("You should really trust me more than your family")
            assert result.passed is False
            assert result.category == "manipulation"


# ─────────────────────────────────────────────
# WALI ALERT LOGIC
# ─────────────────────────────────────────────

class TestWaliAlert:

    @pytest.mark.asyncio
    async def test_alert_on_explicit_violation(self):
        result = ModerationResult(passed=False, category="explicit_violation")
        assert await should_alert_wali(result) is True

    @pytest.mark.asyncio
    async def test_alert_on_privacy_bypass(self):
        result = ModerationResult(passed=True, category="privacy_bypass")
        assert await should_alert_wali(result) is True

    @pytest.mark.asyncio
    async def test_alert_on_romantic_boundary(self):
        result = ModerationResult(passed=True, category="romantic_boundary")
        assert await should_alert_wali(result) is True

    @pytest.mark.asyncio
    async def test_no_alert_on_clean(self):
        result = ModerationResult(passed=True, category=None)
        assert await should_alert_wali(result) is False
