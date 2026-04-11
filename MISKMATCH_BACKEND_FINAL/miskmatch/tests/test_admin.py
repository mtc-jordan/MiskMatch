"""MiskMatch — Admin Dashboard Router Tests"""

import pytest
from datetime import datetime, timezone
from unittest.mock import MagicMock, AsyncMock, patch
from uuid import uuid4

from app.core.database import get_db
from app.routers.auth import get_current_active_user
from app.models.models import (
    User, UserRole, UserStatus, Gender,
    MatchStatus, MessageStatus, SubscriptionTier,
)
from tests.conftest import TEST_USER_ID


# ─────────────────────────────────────────────
# ADMIN USER FIXTURE
# ─────────────────────────────────────────────

ADMIN_USER_ID = "00000000-0000-0000-0000-000000000099"


@pytest.fixture
def admin_user():
    """Mock admin user for admin-only endpoints."""
    user = MagicMock(spec=User)
    user.id = ADMIN_USER_ID
    user.phone = "+962790000099"
    user.email = "admin@miskmatch.app"
    user.role = UserRole.ADMIN
    user.status = UserStatus.ACTIVE
    user.gender = Gender.MALE
    user.phone_verified = True
    user.onboarding_completed = True
    user.subscription_tier = SubscriptionTier.MISK
    user.fcm_token = None
    user.deleted_at = None
    user.created_at = datetime.now(timezone.utc)
    user.last_seen_at = datetime.now(timezone.utc)
    return user


@pytest.fixture
def regular_user():
    """Mock regular (non-admin) user."""
    user = MagicMock(spec=User)
    user.id = TEST_USER_ID
    user.phone = "+962791234567"
    user.email = "user@miskmatch.app"
    user.role = UserRole.USER
    user.status = UserStatus.ACTIVE
    user.gender = Gender.MALE
    user.phone_verified = True
    user.onboarding_completed = True
    user.subscription_tier = SubscriptionTier.BARAKAH
    user.fcm_token = None
    user.deleted_at = None
    user.created_at = datetime.now(timezone.utc)
    user.last_seen_at = None
    return user


@pytest.fixture
def mock_db():
    db = AsyncMock()
    db.commit = AsyncMock()
    db.rollback = AsyncMock()
    db.close = AsyncMock()
    return db


@pytest.fixture(autouse=True)
def _override_deps_admin(admin_user, mock_db):
    """Override FastAPI deps for admin endpoint tests (admin by default)."""
    from app.main import app

    async def _fake_get_db():
        yield mock_db

    app.dependency_overrides[get_db] = _fake_get_db
    app.dependency_overrides[get_current_active_user] = lambda: admin_user
    yield
    app.dependency_overrides.clear()


# ─────────────────────────────────────────────
# ADMIN GUARD
# ─────────────────────────────────────────────

class TestAdminGuard:

    @pytest.mark.asyncio
    async def test_non_admin_gets_403(self, client, regular_user):
        from app.main import app
        app.dependency_overrides[get_current_active_user] = lambda: regular_user
        resp = await client.get("/api/v1/admin/dashboard")
        assert resp.status_code == 403
        assert "Admin access required" in resp.json()["detail"]

    @pytest.mark.asyncio
    async def test_admin_passes_guard(self, client, mock_db):
        # Mock the dashboard DB queries
        mock_uc = MagicMock()
        mock_uc.total = 100
        mock_uc.active = 80
        mock_uc.pending = 15
        mock_uc.banned = 5

        results = [
            MagicMock(one=MagicMock(return_value=mock_uc)),  # user_counts
            MagicMock(scalar=MagicMock(return_value=30)),     # active_matches
            MagicMock(scalar=MagicMock(return_value=50)),     # total_matches
            MagicMock(scalar=MagicMock(return_value=200)),    # messages_today
            MagicMock(scalar=MagicMock(return_value=3)),      # reports_pending
        ]
        mock_db.execute = AsyncMock(side_effect=results)

        resp = await client.get("/api/v1/admin/dashboard")
        assert resp.status_code == 200


# ─────────────────────────────────────────────
# DASHBOARD & ANALYTICS
# ─────────────────────────────────────────────

class TestDashboard:

    @pytest.mark.asyncio
    async def test_dashboard_returns_stats(self, client, mock_db):
        mock_uc = MagicMock()
        mock_uc.total = 500
        mock_uc.active = 400
        mock_uc.pending = 80
        mock_uc.banned = 20

        results = [
            MagicMock(one=MagicMock(return_value=mock_uc)),
            MagicMock(scalar=MagicMock(return_value=120)),
            MagicMock(scalar=MagicMock(return_value=300)),
            MagicMock(scalar=MagicMock(return_value=1500)),
            MagicMock(scalar=MagicMock(return_value=7)),
        ]
        mock_db.execute = AsyncMock(side_effect=results)

        resp = await client.get("/api/v1/admin/dashboard")
        assert resp.status_code == 200
        data = resp.json()
        assert data["total_users"] == 500
        assert data["active_users"] == 400
        assert data["active_matches"] == 120
        assert data["messages_today"] == 1500
        assert data["reports_pending"] == 7

    @pytest.mark.asyncio
    async def test_analytics_returns_metrics(self, client, mock_db):
        reg_row = MagicMock()
        reg_row.day = datetime(2026, 4, 1, tzinfo=timezone.utc)
        reg_row.count = 15

        results = [
            MagicMock(all=MagicMock(return_value=[reg_row])),  # registrations
            MagicMock(scalar=MagicMock(return_value=200)),      # total_matches
            MagicMock(scalar=MagicMock(return_value=80)),       # successful_matches
            MagicMock(scalar=MagicMock(return_value=12.5)),     # avg_messages
            MagicMock(scalar=MagicMock(return_value=5)),        # nikah
            MagicMock(scalar=MagicMock(return_value=300)),      # games
            MagicMock(scalar=MagicMock(return_value=10)),       # calls_today
        ]
        mock_db.execute = AsyncMock(side_effect=results)

        resp = await client.get("/api/v1/admin/analytics?days=30")
        assert resp.status_code == 200
        data = resp.json()
        assert data["total_nikah"] == 5
        assert data["total_games_played"] == 300
        assert len(data["registrations_over_time"]) == 1

    @pytest.mark.asyncio
    async def test_analytics_days_validation(self, client):
        resp = await client.get("/api/v1/admin/analytics?days=0")
        assert resp.status_code == 422

        resp = await client.get("/api/v1/admin/analytics?days=400")
        assert resp.status_code == 422


# ─────────────────────────────────────────────
# USER MANAGEMENT
# ─────────────────────────────────────────────

class TestUserManagement:

    @pytest.mark.asyncio
    async def test_list_users(self, client, mock_db):
        mock_user = MagicMock(spec=User)
        mock_user.id = uuid4()
        mock_user.phone = "+962791111111"
        mock_user.email = "u@m.com"
        mock_user.role = UserRole.USER
        mock_user.status = UserStatus.ACTIVE
        mock_user.gender = Gender.FEMALE
        mock_user.phone_verified = True
        mock_user.onboarding_completed = True
        mock_user.subscription_tier = SubscriptionTier.NOOR
        mock_user.created_at = datetime.now(timezone.utc)
        mock_user.last_seen_at = None

        count_result = MagicMock(scalar=MagicMock(return_value=1))
        users_result = MagicMock()
        users_result.scalars.return_value.all.return_value = [mock_user]

        mock_db.execute = AsyncMock(side_effect=[count_result, users_result])

        resp = await client.get("/api/v1/admin/users")
        assert resp.status_code == 200
        data = resp.json()
        assert data["total"] == 1
        assert len(data["users"]) == 1

    @pytest.mark.asyncio
    async def test_list_users_with_filters(self, client, mock_db):
        count_result = MagicMock(scalar=MagicMock(return_value=0))
        users_result = MagicMock()
        users_result.scalars.return_value.all.return_value = []
        mock_db.execute = AsyncMock(side_effect=[count_result, users_result])

        resp = await client.get("/api/v1/admin/users?status=banned&role=user&search=962")
        assert resp.status_code == 200
        assert resp.json()["total"] == 0

    @pytest.mark.asyncio
    async def test_get_user_detail(self, client, mock_db):
        uid = uuid4()
        mock_user = MagicMock(spec=User)
        mock_user.id = uid
        mock_user.phone = "+962790000001"
        mock_user.email = None
        mock_user.role = UserRole.USER
        mock_user.status = UserStatus.ACTIVE
        mock_user.gender = Gender.MALE
        mock_user.phone_verified = True
        mock_user.onboarding_completed = False
        mock_user.subscription_tier = SubscriptionTier.BARAKAH
        mock_user.created_at = datetime.now(timezone.utc)
        mock_user.last_seen_at = None

        user_result = MagicMock(scalar_one_or_none=MagicMock(return_value=mock_user))
        profile_result = MagicMock(scalar_one_or_none=MagicMock(return_value=None))
        matches_result = MagicMock()
        matches_result.scalars.return_value.all.return_value = []
        reports_result = MagicMock()
        reports_result.scalars.return_value.all.return_value = []

        mock_db.execute = AsyncMock(side_effect=[
            user_result, profile_result, matches_result, reports_result,
        ])

        resp = await client.get(f"/api/v1/admin/users/{uid}")
        assert resp.status_code == 200
        data = resp.json()
        assert data["user"]["phone"] == "+962790000001"
        assert data["profile"] is None
        assert data["matches"] == []

    @pytest.mark.asyncio
    async def test_get_user_detail_not_found(self, client, mock_db):
        mock_db.execute = AsyncMock(
            return_value=MagicMock(scalar_one_or_none=MagicMock(return_value=None))
        )
        resp = await client.get(f"/api/v1/admin/users/{uuid4()}")
        assert resp.status_code == 404

    @pytest.mark.asyncio
    async def test_update_user_status_ban(self, client, mock_db):
        uid = uuid4()
        mock_user = MagicMock(spec=User)
        mock_user.id = uid
        mock_user.role = UserRole.USER
        mock_user.status = UserStatus.ACTIVE

        user_result = MagicMock(scalar_one_or_none=MagicMock(return_value=mock_user))
        matches_result = MagicMock()
        matches_result.scalars.return_value.all.return_value = []

        mock_db.execute = AsyncMock(side_effect=[user_result, matches_result])

        resp = await client.put(
            f"/api/v1/admin/users/{uid}/status",
            json={"status": "banned", "reason": "spam"},
        )
        assert resp.status_code == 200
        assert resp.json()["new_status"] == "banned"

    @pytest.mark.asyncio
    async def test_update_admin_status_forbidden(self, client, mock_db):
        uid = uuid4()
        mock_user = MagicMock(spec=User)
        mock_user.id = uid
        mock_user.role = UserRole.ADMIN
        mock_user.status = UserStatus.ACTIVE

        mock_db.execute = AsyncMock(
            return_value=MagicMock(scalar_one_or_none=MagicMock(return_value=mock_user))
        )

        resp = await client.put(
            f"/api/v1/admin/users/{uid}/status",
            json={"status": "banned"},
        )
        assert resp.status_code == 403

    @pytest.mark.asyncio
    async def test_update_user_role(self, client, mock_db):
        uid = uuid4()
        mock_user = MagicMock(spec=User)
        mock_user.id = uid
        mock_user.role = UserRole.USER

        mock_db.execute = AsyncMock(
            return_value=MagicMock(scalar_one_or_none=MagicMock(return_value=mock_user))
        )

        resp = await client.put(
            f"/api/v1/admin/users/{uid}/role",
            json={"role": "scholar"},
        )
        assert resp.status_code == 200

    @pytest.mark.asyncio
    async def test_promote_to_admin_forbidden(self, client, mock_db):
        uid = uuid4()
        mock_user = MagicMock(spec=User)
        mock_user.id = uid
        mock_user.role = UserRole.USER

        mock_db.execute = AsyncMock(
            return_value=MagicMock(scalar_one_or_none=MagicMock(return_value=mock_user))
        )

        resp = await client.put(
            f"/api/v1/admin/users/{uid}/role",
            json={"role": "admin"},
        )
        assert resp.status_code == 403


# ─────────────────────────────────────────────
# REPORTS
# ─────────────────────────────────────────────

class TestReports:

    @pytest.mark.asyncio
    async def test_list_reports(self, client, mock_db):
        mock_report = MagicMock()
        mock_report.id = uuid4()
        mock_report.reporter_id = uuid4()
        mock_report.reported_id = uuid4()
        mock_report.reason = "harassment"
        mock_report.description = "Rude messages"
        mock_report.evidence_urls = None
        mock_report.is_block = False
        mock_report.status = "pending"
        mock_report.reviewed_by = None
        mock_report.reviewed_at = None
        mock_report.resolution = None
        mock_report.created_at = datetime.now(timezone.utc)

        count_result = MagicMock(scalar=MagicMock(return_value=1))
        reports_result = MagicMock()
        reports_result.scalars.return_value.all.return_value = [mock_report]

        mock_db.execute = AsyncMock(side_effect=[count_result, reports_result])

        resp = await client.get("/api/v1/admin/reports")
        assert resp.status_code == 200
        data = resp.json()
        assert data["total"] == 1
        assert data["reports"][0]["reason"] == "harassment"

    @pytest.mark.asyncio
    async def test_list_reports_with_status_filter(self, client, mock_db):
        count_result = MagicMock(scalar=MagicMock(return_value=0))
        reports_result = MagicMock()
        reports_result.scalars.return_value.all.return_value = []
        mock_db.execute = AsyncMock(side_effect=[count_result, reports_result])

        resp = await client.get("/api/v1/admin/reports?status=pending")
        assert resp.status_code == 200

    @pytest.mark.asyncio
    async def test_report_detail_not_found(self, client, mock_db):
        mock_db.execute = AsyncMock(
            return_value=MagicMock(scalar_one_or_none=MagicMock(return_value=None))
        )
        resp = await client.get(f"/api/v1/admin/reports/{uuid4()}")
        assert resp.status_code == 404

    @pytest.mark.asyncio
    async def test_resolve_report_dismiss(self, client, mock_db, admin_user):
        report_id = uuid4()
        mock_report = MagicMock()
        mock_report.id = report_id
        mock_report.status = "pending"
        mock_report.reported_id = uuid4()
        mock_report.resolution = None

        mock_db.execute = AsyncMock(
            return_value=MagicMock(scalar_one_or_none=MagicMock(return_value=mock_report))
        )

        resp = await client.put(
            f"/api/v1/admin/reports/{report_id}/resolve",
            json={"action": "dismiss", "resolution_note": "Unfounded complaint"},
        )
        assert resp.status_code == 200
        assert resp.json()["action"] == "dismiss"

    @pytest.mark.asyncio
    async def test_resolve_report_warn(self, client, mock_db, admin_user):
        report_id = uuid4()
        mock_report = MagicMock()
        mock_report.id = report_id
        mock_report.status = "pending"
        mock_report.reported_id = uuid4()
        mock_report.resolution = None

        mock_db.execute = AsyncMock(
            return_value=MagicMock(scalar_one_or_none=MagicMock(return_value=mock_report))
        )

        resp = await client.put(
            f"/api/v1/admin/reports/{report_id}/resolve",
            json={"action": "warn"},
        )
        assert resp.status_code == 200
        assert "warning" in resp.json()["message"].lower()

    @pytest.mark.asyncio
    async def test_resolve_report_ban(self, client, mock_db, admin_user):
        report_id = uuid4()
        reported_id = uuid4()
        mock_report = MagicMock()
        mock_report.id = report_id
        mock_report.status = "pending"
        mock_report.reported_id = reported_id
        mock_report.resolution = None

        reported_user = MagicMock(spec=User)
        reported_user.id = reported_id
        reported_user.role = UserRole.USER
        reported_user.status = UserStatus.ACTIVE

        matches_result = MagicMock()
        matches_result.scalars.return_value.all.return_value = []

        mock_db.execute = AsyncMock(side_effect=[
            MagicMock(scalar_one_or_none=MagicMock(return_value=mock_report)),
            MagicMock(scalar_one_or_none=MagicMock(return_value=reported_user)),
            matches_result,
        ])

        resp = await client.put(
            f"/api/v1/admin/reports/{report_id}/resolve",
            json={"action": "ban"},
        )
        assert resp.status_code == 200
        assert "banned" in resp.json()["message"].lower()

    @pytest.mark.asyncio
    async def test_resolve_already_resolved_409(self, client, mock_db):
        report_id = uuid4()
        mock_report = MagicMock()
        mock_report.id = report_id
        mock_report.status = "resolved"

        mock_db.execute = AsyncMock(
            return_value=MagicMock(scalar_one_or_none=MagicMock(return_value=mock_report))
        )

        resp = await client.put(
            f"/api/v1/admin/reports/{report_id}/resolve",
            json={"action": "dismiss"},
        )
        assert resp.status_code == 409

    @pytest.mark.asyncio
    async def test_resolve_invalid_action_422(self, client, mock_db):
        report_id = uuid4()
        mock_report = MagicMock()
        mock_report.id = report_id
        mock_report.status = "pending"

        mock_db.execute = AsyncMock(
            return_value=MagicMock(scalar_one_or_none=MagicMock(return_value=mock_report))
        )

        resp = await client.put(
            f"/api/v1/admin/reports/{report_id}/resolve",
            json={"action": "execute"},
        )
        assert resp.status_code == 422


# ─────────────────────────────────────────────
# FLAGGED MESSAGES
# ─────────────────────────────────────────────

class TestFlaggedMessages:

    @pytest.mark.asyncio
    async def test_list_flagged_messages(self, client, mock_db):
        msg = MagicMock()
        msg.id = uuid4()
        msg.match_id = uuid4()
        msg.sender_id = uuid4()
        msg.content = "inappropriate content"
        msg.content_type = "text"
        msg.moderation_reason = "explicit_violation"
        msg.created_at = datetime.now(timezone.utc)

        count_result = MagicMock(scalar=MagicMock(return_value=1))
        rows_result = MagicMock(all=MagicMock(return_value=[(msg, "+962790001111")]))
        mock_db.execute = AsyncMock(side_effect=[count_result, rows_result])

        resp = await client.get("/api/v1/admin/flagged-messages")
        assert resp.status_code == 200
        data = resp.json()
        assert data["total"] == 1
        assert data["messages"][0]["moderation_reason"] == "explicit_violation"

    @pytest.mark.asyncio
    async def test_flagged_messages_empty(self, client, mock_db):
        count_result = MagicMock(scalar=MagicMock(return_value=0))
        rows_result = MagicMock(all=MagicMock(return_value=[]))
        mock_db.execute = AsyncMock(side_effect=[count_result, rows_result])

        resp = await client.get("/api/v1/admin/flagged-messages")
        assert resp.status_code == 200
        assert resp.json()["messages"] == []


# ─────────────────────────────────────────────
# MATCH MANAGEMENT
# ─────────────────────────────────────────────

class TestMatchManagement:

    @pytest.mark.asyncio
    async def test_list_matches(self, client, mock_db):
        match = MagicMock()
        match.id = uuid4()
        match.sender_id = uuid4()
        match.receiver_id = uuid4()
        match.status = MatchStatus.ACTIVE
        match.compatibility_score = 87.5
        match.created_at = datetime.now(timezone.utc)
        match.became_mutual_at = datetime.now(timezone.utc)
        match.nikah_date = None
        match.closed_reason = None

        count_result = MagicMock(scalar=MagicMock(return_value=1))
        rows_result = MagicMock(all=MagicMock(return_value=[
            (match, "+962790001111", "+962790002222"),
        ]))
        mock_db.execute = AsyncMock(side_effect=[count_result, rows_result])

        resp = await client.get("/api/v1/admin/matches")
        assert resp.status_code == 200
        data = resp.json()
        assert data["total"] == 1
        assert data["matches"][0]["compatibility_score"] == 87.5

    @pytest.mark.asyncio
    async def test_list_matches_with_filters(self, client, mock_db):
        count_result = MagicMock(scalar=MagicMock(return_value=0))
        rows_result = MagicMock(all=MagicMock(return_value=[]))
        mock_db.execute = AsyncMock(side_effect=[count_result, rows_result])

        resp = await client.get("/api/v1/admin/matches?status=nikah")
        assert resp.status_code == 200
        assert resp.json()["total"] == 0

    @pytest.mark.asyncio
    async def test_match_funnel_stats(self, client, mock_db):
        funnel_rows = [
            MagicMock(status=MatchStatus.PENDING, count=100),
            MagicMock(status=MatchStatus.MUTUAL, count=40),
            MagicMock(status=MatchStatus.APPROVED, count=20),
            MagicMock(status=MatchStatus.ACTIVE, count=15),
            MagicMock(status=MatchStatus.NIKAH, count=5),
            MagicMock(status=MatchStatus.CLOSED, count=10),
            MagicMock(status=MatchStatus.BLOCKED, count=3),
        ]
        mock_db.execute = AsyncMock(
            return_value=MagicMock(all=MagicMock(return_value=funnel_rows))
        )

        resp = await client.get("/api/v1/admin/matches/stats")
        assert resp.status_code == 200
        data = resp.json()
        assert data["total_pending"] == 100
        assert data["total_nikah"] == 5
        assert data["pending_to_mutual_rate"] > 0

    @pytest.mark.asyncio
    async def test_match_funnel_empty(self, client, mock_db):
        mock_db.execute = AsyncMock(
            return_value=MagicMock(all=MagicMock(return_value=[]))
        )

        resp = await client.get("/api/v1/admin/matches/stats")
        assert resp.status_code == 200
        data = resp.json()
        assert data["total_pending"] == 0
        assert data["pending_to_mutual_rate"] == 0.0
