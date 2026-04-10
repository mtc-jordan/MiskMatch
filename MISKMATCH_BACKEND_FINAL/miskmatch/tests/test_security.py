"""
MiskMatch — Security & Sanitization Tests
Tests for password hashing, JWT tokens, input sanitization, and token blacklist.
"""

from datetime import timedelta
from unittest.mock import AsyncMock, patch

import pytest
from jose import JWTError, jwt

from app.core.config import settings
from app.core.security import (
    create_access_token,
    create_otp_token,
    create_refresh_token,
    decode_token,
    hash_password,
    is_password_strong,
    verify_password,
)
from app.core.sanitize import sanitize_dict_values, sanitize_text
from app.core.redis import (
    blacklist_all_user_tokens,
    blacklist_token,
    is_token_blacklisted,
)


# ═══════════════════════════════════════════════════════════════════
# 1. Password Hashing
# ═══════════════════════════════════════════════════════════════════


class TestPasswordHashing:
    """Tests for bcrypt password hashing and verification."""

    def test_hash_and_verify_success(self):
        plain = "SecurePass123"
        hashed = hash_password(plain)
        assert verify_password(plain, hashed) is True

    def test_verify_wrong_password(self):
        hashed = hash_password("CorrectPassword1")
        assert verify_password("WrongPassword1", hashed) is False

    def test_hash_produces_different_hashes(self):
        """Same input should yield different hashes due to random salts."""
        plain = "SamePassword1"
        hash1 = hash_password(plain)
        hash2 = hash_password(plain)
        assert hash1 != hash2
        # Both should still verify correctly
        assert verify_password(plain, hash1) is True
        assert verify_password(plain, hash2) is True


# ═══════════════════════════════════════════════════════════════════
# 2. Password Strength
# ═══════════════════════════════════════════════════════════════════


class TestPasswordStrength:
    """Tests for password strength validation rules."""

    def test_strong_password(self):
        assert is_password_strong("Str0ngPass") is True

    def test_too_short(self):
        assert is_password_strong("Sh0rt") is False

    def test_no_uppercase(self):
        assert is_password_strong("alllowercase1") is False

    def test_no_lowercase(self):
        assert is_password_strong("ALLUPPERCASE1") is False

    def test_no_digit(self):
        assert is_password_strong("NoDigitsHere") is False


# ═══════════════════════════════════════════════════════════════════
# 3. JWT Tokens
# ═══════════════════════════════════════════════════════════════════


class TestJWT:
    """Tests for JWT access, refresh, and OTP token creation/decoding."""

    def test_create_access_token_valid(self):
        token = create_access_token(subject="user-123")
        payload = decode_token(token)
        assert payload["sub"] == "user-123"

    def test_access_token_has_jti(self):
        token = create_access_token(subject="user-123")
        payload = decode_token(token)
        assert "jti" in payload
        assert len(payload["jti"]) > 0

    def test_access_token_has_correct_type(self):
        token = create_access_token(subject="user-123")
        payload = decode_token(token)
        assert payload["type"] == "access"

    def test_create_refresh_token_valid(self):
        token = create_refresh_token(subject="user-456")
        payload = decode_token(token)
        assert payload["sub"] == "user-456"
        assert payload["type"] == "refresh"

    def test_refresh_token_has_jti(self):
        token = create_refresh_token(subject="user-456")
        payload = decode_token(token)
        assert "jti" in payload
        assert len(payload["jti"]) > 0

    def test_decode_expired_token(self):
        """A token created with a negative timedelta should be expired."""
        expire = timedelta(minutes=-1)
        payload = {
            "sub": "user-expired",
            "exp": __import__("datetime").datetime.now(
                __import__("datetime").timezone.utc
            )
            + expire,
            "type": "access",
        }
        token = jwt.encode(
            payload, settings.SECRET_KEY, algorithm=settings.ALGORITHM
        )
        with pytest.raises(JWTError):
            decode_token(token)

    def test_decode_invalid_token(self):
        """Garbage string should raise JWTError."""
        with pytest.raises(JWTError):
            decode_token("this.is.not.a.valid.jwt")

    def test_otp_token_creation_and_decode(self):
        phone = "+962791234567"
        otp = "123456"
        token = create_otp_token(phone, otp)
        payload = decode_token(token)
        assert payload["sub"] == phone
        assert payload["otp"] == otp
        assert payload["type"] == "otp"


# ═══════════════════════════════════════════════════════════════════
# 4. Sanitization
# ═══════════════════════════════════════════════════════════════════


class TestSanitization:
    """Tests for HTML/XSS sanitization and Unicode safety."""

    def test_strip_html_tags(self):
        assert sanitize_text("<b>hello</b>") == "hello"

    def test_strip_script_tags(self):
        result = sanitize_text("<script>alert('xss')</script>")
        assert "<script>" not in result
        assert "</script>" not in result

    def test_strip_xss_event_handlers(self):
        result = sanitize_text('img onerror=alert(1)')
        assert "onerror=" not in result

    def test_strip_javascript_url(self):
        result = sanitize_text("javascript:alert(1)")
        assert "javascript:" not in result

    def test_preserve_arabic_text(self):
        arabic = "بسم الله الرحمن الرحيم"
        assert sanitize_text(arabic) == arabic

    def test_preserve_newlines(self):
        text = "line one\nline two\nline three"
        result = sanitize_text(text)
        assert "\n" in result
        assert "line one" in result
        assert "line three" in result

    def test_collapse_whitespace(self):
        result = sanitize_text("too    many     spaces")
        assert result == "too many spaces"

    def test_empty_string(self):
        assert sanitize_text("") == ""

    def test_sanitize_dict_values(self):
        dirty = {
            "name": "<b>Ahmad</b>",
            "bio": '<script>alert("xss")</script>Safe bio',
            "nested": {
                "value": "<i>italic</i>",
            },
            "count": 42,
        }
        clean = sanitize_dict_values(dirty)
        assert clean["name"] == "Ahmad"
        assert "<script>" not in clean["bio"]
        assert clean["nested"]["value"] == "italic"
        assert clean["count"] == 42


# ═══════════════════════════════════════════════════════════════════
# 5. Token Blacklist (mocked Redis)
# ═══════════════════════════════════════════════════════════════════


class TestTokenBlacklist:
    """Tests for Redis-backed token blacklist operations."""

    @pytest.mark.asyncio
    async def test_blacklist_token(self, mock_redis):
        jti = "test-jti-abc123"
        ttl = 3600
        await blacklist_token(jti, ttl)
        mock_redis.setex.assert_awaited_once_with(
            f"miskmatch:token:blacklist:{jti}", ttl, "1"
        )

    @pytest.mark.asyncio
    async def test_is_blacklisted_true(self, mock_redis):
        mock_redis.exists.return_value = 1
        result = await is_token_blacklisted("revoked-jti")
        assert result is True
        mock_redis.exists.assert_awaited_once_with(
            "miskmatch:token:blacklist:revoked-jti"
        )

    @pytest.mark.asyncio
    async def test_is_blacklisted_false(self, mock_redis):
        mock_redis.exists.return_value = 0
        result = await is_token_blacklisted("valid-jti")
        assert result is False

    @pytest.mark.asyncio
    async def test_blacklist_all_user_tokens(self, mock_redis):
        user_id = "user-to-revoke"
        await blacklist_all_user_tokens(user_id)
        mock_redis.incr.assert_awaited_once_with(
            f"miskmatch:token:version:{user_id}"
        )
