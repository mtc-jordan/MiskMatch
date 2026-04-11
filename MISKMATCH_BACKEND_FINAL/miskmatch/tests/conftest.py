"""
MiskMatch — Test Configuration & Shared Fixtures
"""

import os
import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from uuid import UUID
from httpx import AsyncClient, ASGITransport

# Force test environment before any app imports
# Use asyncpg URL (matches real driver) — tests mock DB calls, no actual connection needed
os.environ.setdefault("ENVIRONMENT", "development")
os.environ.setdefault("SECRET_KEY", "test-secret-key-minimum-32-characters-for-jwt")
os.environ.setdefault("DATABASE_URL", "postgresql+asyncpg://test:test@localhost:5433/miskmatch_test")
os.environ.setdefault("DATABASE_URL_SYNC", "postgresql://test:test@localhost:5433/miskmatch_test")
os.environ.setdefault("REDIS_URL", "redis://localhost:6379/1")
os.environ.setdefault("DEBUG", "true")

from app.main import app
from app.core.security import (
    create_access_token,
    create_refresh_token,
    hash_password,
)


# ── Test HTTP Client ────────────────────────────────────────────


@pytest.fixture
async def client():
    """Async HTTP test client for the FastAPI app."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


# ── Auth Fixtures ───────────────────────────────────────────────

TEST_USER_ID = "00000000-0000-0000-0000-000000000001"
TEST_USER_PHONE = "+962791234567"
TEST_PASSWORD = "TestPass123"
TEST_PASSWORD_HASH = hash_password(TEST_PASSWORD)


@pytest.fixture
def test_user():
    """Mock User ORM object."""
    user = MagicMock()
    user.id = UUID(TEST_USER_ID)
    user.phone = TEST_USER_PHONE
    user.email = "test@miskmatch.app"
    user.hashed_password = TEST_PASSWORD_HASH
    user.status = MagicMock()
    user.status.value = "active"
    user.status.__eq__ = lambda self, other: self.value == getattr(other, "value", other)
    user.role = MagicMock()
    user.role.value = "user"
    user.gender = MagicMock()
    user.gender.value = "male"
    user.phone_verified = True
    user.onboarding_completed = True
    user.fcm_token = "test-fcm-token-12345"
    user.deleted_at = None
    return user


@pytest.fixture
def access_token():
    """Valid JWT access token for test user."""
    return create_access_token(
        subject=TEST_USER_ID,
        extra_claims={"role": "user", "gender": "male"},
    )


@pytest.fixture
def refresh_token():
    """Valid JWT refresh token for test user."""
    return create_refresh_token(subject=TEST_USER_ID)


@pytest.fixture
def auth_headers(access_token):
    """Authorization headers with Bearer token."""
    return {"Authorization": f"Bearer {access_token}"}


# ── Redis Mock ──────────────────────────────────────────────────


@pytest.fixture(autouse=True)
def mock_redis():
    """Mock Redis for all tests to avoid requiring a running Redis instance."""
    with patch("app.core.redis.get_redis") as mock_get:
        mock_r = AsyncMock()
        mock_r.exists.return_value = 0  # no blacklisted tokens by default
        mock_r.setex.return_value = True
        mock_r.incr.return_value = 1
        mock_r.get.return_value = None
        mock_r.zremrangebyscore.return_value = 0
        mock_r.zcard.return_value = 0
        mock_r.zadd.return_value = 1
        mock_r.expire.return_value = True
        mock_r.pipeline.return_value = mock_r  # pipeline returns self
        mock_r.execute.return_value = [0, 0, 1, True]  # rate limit responses
        mock_get.return_value = mock_r
        yield mock_r


# ── Database Mock Helpers ───────────────────────────────────────


@pytest.fixture
def mock_db():
    """Mock async database session."""
    db = AsyncMock()
    db.commit = AsyncMock()
    db.rollback = AsyncMock()
    db.close = AsyncMock()
    return db


def mock_db_result(scalar_value=None, scalars_value=None):
    """Create a mock DB execute result."""
    result = MagicMock()
    result.scalar_one_or_none.return_value = scalar_value
    if scalars_value is not None:
        result.scalars.return_value.all.return_value = scalars_value
    else:
        result.scalars.return_value.all.return_value = []
    return result
