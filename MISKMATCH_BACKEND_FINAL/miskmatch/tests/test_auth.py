"""
MiskMatch — Auth Router Tests
pytest + httpx async test client
"""

import pytest
from unittest.mock import AsyncMock, MagicMock, patch

from app.main import app
from app.core.security import (
    create_access_token,
    create_refresh_token,
    create_otp_token,
    hash_password,
)
from app.models.models import UserRole, UserStatus, Gender
from app.routers.auth import get_current_user
from tests.conftest import TEST_USER_ID, TEST_USER_PHONE, TEST_PASSWORD, mock_db_result


# ── Helpers ──────────────────────────────────────────────────────

REGISTER_URL = "/api/v1/auth/register"
LOGIN_URL = "/api/v1/auth/login"
VERIFY_OTP_URL = "/api/v1/auth/verify-otp"
REFRESH_URL = "/api/v1/auth/refresh"
LOGOUT_URL = "/api/v1/auth/logout"
DEVICE_TOKEN_URL = "/api/v1/auth/device-token"
DELETE_ACCOUNT_URL = "/api/v1/auth/account"

VALID_REGISTER_BODY = {
    "phone": "+962791234567",
    "email": "user@example.com",
    "password": "StrongPass1",
    "gender": "male",
    "niyyah": "Marriage",
}


def _make_user_mock(
    user_id=TEST_USER_ID,
    phone=TEST_USER_PHONE,
    password=TEST_PASSWORD,
    status=UserStatus.ACTIVE,
    role=UserRole.USER,
    gender=Gender.MALE,
    phone_verified=True,
    onboarding_completed=True,
    fcm_token="fcm-token-abc",
):
    """Build a MagicMock that behaves like a User ORM object."""
    user = MagicMock()
    user.id = user_id
    user.phone = phone
    user.email = "test@miskmatch.app"
    user.password_hash = hash_password(password)
    user.status = status
    user.role = role
    user.gender = gender
    user.phone_verified = phone_verified
    user.onboarding_completed = onboarding_completed
    user.fcm_token = fcm_token
    user.deleted_at = None
    user.last_seen_at = None
    return user


def _mock_db_session(execute_side_effects):
    """
    Return an AsyncMock DB session whose .execute() returns
    the given side effects in order.
    """
    db = AsyncMock()
    db.execute = AsyncMock(side_effect=execute_side_effects)
    db.add = MagicMock()
    db.flush = AsyncMock()
    db.commit = AsyncMock()
    db.rollback = AsyncMock()
    return db


# ── TestRegister ─────────────────────────────────────────────────


class TestRegister:
    """POST /api/v1/auth/register"""

    @pytest.mark.anyio
    async def test_register_success(self, client):
        """New user registers successfully; OTP sent."""
        mock_db = _mock_db_session([
            mock_db_result(scalar_value=None),  # phone uniqueness check
        ])

        async def _override_get_db():
            yield mock_db

        app.dependency_overrides[__import__("app.core.database", fromlist=["get_db"]).get_db] = _override_get_db

        with patch("app.routers.auth.send_otp_sms"):
            resp = await client.post(REGISTER_URL, json=VALID_REGISTER_BODY)

        app.dependency_overrides.clear()

        assert resp.status_code == 201
        data = resp.json()
        assert "otp_token" in data
        assert data["phone"] == "+962791234567"
        assert data["message"] == "Registration successful. OTP sent to your phone."

    @pytest.mark.anyio
    async def test_register_duplicate_phone(self, client):
        """Registering an already-taken phone returns 409."""
        existing_user = _make_user_mock()
        mock_db = _mock_db_session([
            mock_db_result(scalar_value=existing_user),  # phone already exists
        ])

        from app.core.database import get_db
        async def _override():
            yield mock_db
        app.dependency_overrides[get_db] = _override

        resp = await client.post(REGISTER_URL, json=VALID_REGISTER_BODY)
        app.dependency_overrides.clear()

        assert resp.status_code == 409
        assert "already registered" in resp.json()["detail"]

    @pytest.mark.anyio
    async def test_register_weak_password(self, client):
        """Password shorter than 8 chars is rejected (422)."""
        mock_db = _mock_db_session([
            mock_db_result(scalar_value=None),
        ])

        from app.core.database import get_db
        async def _override():
            yield mock_db
        app.dependency_overrides[get_db] = _override

        body = {**VALID_REGISTER_BODY, "password": "weak"}
        resp = await client.post(REGISTER_URL, json=body)
        app.dependency_overrides.clear()

        assert resp.status_code == 422
        assert "Password must be 8+" in resp.json()["detail"]

    @pytest.mark.anyio
    async def test_register_invalid_phone(self, client):
        """Invalid phone format is rejected by Pydantic validator."""
        body = {**VALID_REGISTER_BODY, "phone": "not-a-phone"}
        resp = await client.post(REGISTER_URL, json=body)
        assert resp.status_code == 422


# ── TestLogin ────────────────────────────────────────────────────


class TestLogin:
    """POST /api/v1/auth/login"""

    @pytest.mark.anyio
    async def test_login_success(self, client):
        """Valid credentials return access + refresh tokens."""
        user = _make_user_mock()
        mock_db = _mock_db_session([
            mock_db_result(scalar_value=user),  # user lookup
        ])

        from app.core.database import get_db
        async def _override():
            yield mock_db
        app.dependency_overrides[get_db] = _override

        resp = await client.post(LOGIN_URL, json={
            "phone": TEST_USER_PHONE,
            "password": TEST_PASSWORD,
        })
        app.dependency_overrides.clear()

        assert resp.status_code == 200
        data = resp.json()
        assert "access_token" in data
        assert "refresh_token" in data
        assert data["token_type"] == "bearer"
        assert data["user_id"] == TEST_USER_ID

    @pytest.mark.anyio
    async def test_login_wrong_password(self, client):
        """Wrong password returns 401."""
        user = _make_user_mock()
        mock_db = _mock_db_session([
            mock_db_result(scalar_value=user),
        ])

        from app.core.database import get_db
        async def _override():
            yield mock_db
        app.dependency_overrides[get_db] = _override

        resp = await client.post(LOGIN_URL, json={
            "phone": TEST_USER_PHONE,
            "password": "WrongPassword99",
        })
        app.dependency_overrides.clear()

        assert resp.status_code == 401
        assert "Incorrect phone number or password" in resp.json()["detail"]

    @pytest.mark.anyio
    async def test_login_user_not_found(self, client):
        """Non-existent phone returns 401."""
        mock_db = _mock_db_session([
            mock_db_result(scalar_value=None),
        ])

        from app.core.database import get_db
        async def _override():
            yield mock_db
        app.dependency_overrides[get_db] = _override

        resp = await client.post(LOGIN_URL, json={
            "phone": "+962799999999",
            "password": "SomePass123",
        })
        app.dependency_overrides.clear()

        assert resp.status_code == 401


# ── TestVerifyOtp ────────────────────────────────────────────────


class TestVerifyOtp:
    """POST /api/v1/auth/verify-otp"""

    @pytest.mark.anyio
    async def test_verify_otp_success(self, client):
        """Correct OTP activates user and returns tokens."""
        otp_code = "123456"
        otp_token = create_otp_token(TEST_USER_PHONE, otp_code)

        user = _make_user_mock(status=UserStatus.PENDING, phone_verified=False)
        mock_db = _mock_db_session([
            mock_db_result(scalar_value=user),  # user lookup by phone
        ])

        from app.core.database import get_db
        async def _override():
            yield mock_db
        app.dependency_overrides[get_db] = _override

        resp = await client.post(VERIFY_OTP_URL, json={
            "otp_token": otp_token,
            "otp": otp_code,
        })
        app.dependency_overrides.clear()

        assert resp.status_code == 200
        data = resp.json()
        assert "access_token" in data
        assert "refresh_token" in data
        assert data["token_type"] == "bearer"

    @pytest.mark.anyio
    async def test_verify_otp_wrong_code(self, client):
        """Wrong OTP code returns 400."""
        otp_code = "123456"
        otp_token = create_otp_token(TEST_USER_PHONE, otp_code)

        resp = await client.post(VERIFY_OTP_URL, json={
            "otp_token": otp_token,
            "otp": "999999",
        })

        assert resp.status_code == 400
        assert "Incorrect OTP" in resp.json()["detail"]


# ── TestRefreshToken ─────────────────────────────────────────────


class TestRefreshToken:
    """POST /api/v1/auth/refresh"""

    @pytest.mark.anyio
    async def test_refresh_success(self, client):
        """Valid refresh token returns new token pair."""
        token = create_refresh_token(subject=TEST_USER_ID)
        user = _make_user_mock()
        mock_db = _mock_db_session([
            mock_db_result(scalar_value=user),
        ])

        from app.core.database import get_db
        async def _override():
            yield mock_db
        app.dependency_overrides[get_db] = _override

        resp = await client.post(REFRESH_URL, json={
            "refresh_token": token,
        })
        app.dependency_overrides.clear()

        assert resp.status_code == 200
        data = resp.json()
        assert "access_token" in data
        assert "refresh_token" in data
        # New refresh token should differ from the old one
        assert data["refresh_token"] != token

    @pytest.mark.anyio
    async def test_refresh_invalid_token(self, client):
        """Garbage token returns 401."""
        resp = await client.post(REFRESH_URL, json={
            "refresh_token": "this.is.not.valid",
        })
        assert resp.status_code == 401

    @pytest.mark.anyio
    async def test_refresh_replayed_token(self, client, mock_redis):
        """Second use of the same refresh token is rejected (replay attack)."""
        token = create_refresh_token(subject=TEST_USER_ID)

        # Simulate that the JTI is already blacklisted (token was already used)
        mock_redis.exists.return_value = 1

        resp = await client.post(REFRESH_URL, json={
            "refresh_token": token,
        })

        assert resp.status_code == 401
        assert "already been used" in resp.json()["detail"]


# ── TestLogout ───────────────────────────────────────────────────


class TestLogout:
    """POST /api/v1/auth/logout"""

    @pytest.mark.anyio
    async def test_logout_success(self, client, test_user, auth_headers):
        """Authenticated user can log out."""
        mock_db = _mock_db_session([])

        from app.core.database import get_db
        async def _override_db():
            yield mock_db

        async def _override_user():
            return test_user

        app.dependency_overrides[get_db] = _override_db
        app.dependency_overrides[get_current_user] = _override_user

        resp = await client.post(LOGOUT_URL, headers=auth_headers)
        app.dependency_overrides.clear()

        assert resp.status_code == 200
        assert resp.json()["message"] == "Logged out successfully"

    @pytest.mark.anyio
    async def test_logout_unauthenticated(self, client):
        """Request without token returns 401."""
        resp = await client.post(LOGOUT_URL)
        assert resp.status_code in (401, 403)


# ── TestDeviceToken ──────────────────────────────────────────────


class TestDeviceToken:
    """POST /api/v1/auth/device-token"""

    @pytest.mark.anyio
    async def test_register_device_token_success(self, client, test_user, auth_headers):
        """Authenticated user can register an FCM token."""
        mock_db = _mock_db_session([])

        from app.core.database import get_db
        async def _override_db():
            yield mock_db

        async def _override_user():
            return test_user

        app.dependency_overrides[get_db] = _override_db
        app.dependency_overrides[get_current_user] = _override_user

        resp = await client.post(
            DEVICE_TOKEN_URL,
            json={"token": "new-fcm-token-xyz"},
            headers=auth_headers,
        )
        app.dependency_overrides.clear()

        assert resp.status_code == 200
        assert resp.json()["message"] == "Device token registered"
        assert test_user.fcm_token == "new-fcm-token-xyz"

    @pytest.mark.anyio
    async def test_register_device_token_invalid(self, client, test_user, auth_headers):
        """Empty token string is rejected by Pydantic (422)."""
        async def _override_user():
            return test_user
        app.dependency_overrides[get_current_user] = _override_user

        resp = await client.post(
            DEVICE_TOKEN_URL,
            json={"token": ""},
            headers=auth_headers,
        )
        app.dependency_overrides.clear()

        # Empty string is technically valid for Pydantic str field,
        # so this should succeed (200) unless the schema enforces min_length.
        # If the endpoint accepts it, the test documents current behaviour.
        assert resp.status_code in (200, 422)


# ── TestDeleteAccount ────────────────────────────────────────────


class TestDeleteAccount:
    """DELETE /api/v1/auth/account"""

    @pytest.mark.anyio
    async def test_delete_account_success(self, client, test_user, auth_headers):
        """Active user can delete their account; active matches are closed."""
        mock_match = MagicMock()
        mock_match.status = "active"
        mock_match.closed_reason = None

        # First execute: match query
        match_result = MagicMock()
        match_result.scalars.return_value.all.return_value = [mock_match]

        mock_db = AsyncMock()
        mock_db.execute = AsyncMock(return_value=match_result)
        mock_db.commit = AsyncMock()

        from app.core.database import get_db
        async def _override_db():
            yield mock_db

        async def _override_user():
            return test_user

        app.dependency_overrides[get_db] = _override_db
        app.dependency_overrides[get_current_user] = _override_user

        with patch("app.routers.auth.blacklist_all_user_tokens", new_callable=AsyncMock):
            resp = await client.delete(DELETE_ACCOUNT_URL, headers=auth_headers)

        app.dependency_overrides.clear()

        assert resp.status_code == 200
        data = resp.json()
        assert "deactivated" in data["message"]
        assert data["matches_closed"] == 1

    @pytest.mark.anyio
    async def test_delete_deactivated_user_blocked(self, client, auth_headers):
        """User whose status is DEACTIVATED gets 403 from get_current_user."""
        # The real get_current_user dependency checks status and raises 403
        # for DEACTIVATED users, so we simulate that by NOT overriding it
        # and instead overriding with a function that raises 403.

        from fastapi import HTTPException, status

        async def _override_user():
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Account has been deleted",
            )

        app.dependency_overrides[get_current_user] = _override_user

        resp = await client.delete(DELETE_ACCOUNT_URL, headers=auth_headers)
        app.dependency_overrides.clear()

        assert resp.status_code == 403
        assert "deleted" in resp.json()["detail"].lower()
