"""MiskMatch — Public Reports Router Tests

Covers the user-facing endpoints in app/routers/reports.py:
    POST /reports         File a report against another user
    GET  /reports/me      List reports I have submitted

The admin-side review flow (list / detail / resolve) is covered
by tests in test_admin.py.
"""

import pytest
from datetime import datetime, timezone
from unittest.mock import MagicMock, AsyncMock
from uuid import UUID, uuid4

from app.main import app
from app.core.database import get_db
from app.routers.auth import get_current_active_user
from app.models.models import Report, User, UserStatus

from tests.conftest import TEST_USER_ID


# ─────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────

OTHER_USER_ID = uuid4()


def _make_reported_user(user_id=None, status=UserStatus.ACTIVE):
    """Build a mock reported User row."""
    u = MagicMock(spec=User)
    u.id = user_id or OTHER_USER_ID
    u.status = status
    return u


def _make_report_row(
    reporter_id=TEST_USER_ID,
    reported_id=None,
    reason="harassment",
    description="They sent unwanted messages.",
    is_block=False,
    report_status="pending",
):
    """Build a mock Report ORM row that survives Pydantic from_attributes."""
    r = MagicMock(spec=Report)
    r.id = uuid4()
    r.reporter_id = UUID(reporter_id) if isinstance(reporter_id, str) else reporter_id
    r.reported_id = reported_id or OTHER_USER_ID
    r.reason = reason
    r.description = description
    r.evidence_urls = None
    r.is_block = is_block
    r.status = report_status
    r.reviewed_by = None
    r.reviewed_at = None
    r.resolution = None
    r.created_at = datetime.now(timezone.utc)
    return r


@pytest.fixture(autouse=True)
def _override_deps(test_user, mock_db):
    """Override auth + db deps for every test in this module."""
    async def _fake_get_db():
        yield mock_db

    app.dependency_overrides[get_db] = _fake_get_db
    app.dependency_overrides[get_current_active_user] = lambda: test_user
    yield
    app.dependency_overrides.clear()


# ─────────────────────────────────────────────
# POST /reports — CREATE REPORT
# ─────────────────────────────────────────────

class TestCreateReport:

    @pytest.mark.asyncio
    async def test_create_report_success(self, client, mock_db):
        """Happy path: file a report against another active user."""
        reported = _make_reported_user()

        # The router executes one SELECT (verify reported user) before insert.
        mock_db.execute = AsyncMock(
            return_value=MagicMock(
                scalar_one_or_none=MagicMock(return_value=reported)
            )
        )

        # After db.refresh, the Report row's fields must serialise.
        async def _refresh(obj):
            obj.id = uuid4()
            obj.reporter_id = UUID(TEST_USER_ID)
            obj.reported_id = OTHER_USER_ID
            obj.reason = "harassment"
            obj.description = "They sent unwanted messages."
            obj.evidence_urls = None
            obj.is_block = False
            obj.status = "pending"
            obj.reviewed_by = None
            obj.reviewed_at = None
            obj.resolution = None
            obj.created_at = datetime.now(timezone.utc)

        mock_db.refresh = AsyncMock(side_effect=_refresh)
        mock_db.add = MagicMock()

        resp = await client.post(
            "/api/v1/reports",
            json={
                "reported_id": str(OTHER_USER_ID),
                "reason":      "harassment",
                "description": "They sent unwanted messages.",
                "is_block":    False,
            },
        )

        assert resp.status_code == 201, resp.text
        body = resp.json()
        assert body["reason"] == "harassment"
        assert body["status"] == "pending"
        assert body["is_block"] is False
        # The router must have committed and added the row exactly once.
        mock_db.add.assert_called_once()
        mock_db.commit.assert_awaited()

    @pytest.mark.asyncio
    async def test_create_report_with_block_flag(self, client, mock_db):
        """is_block=True is persisted on the Report row."""
        reported = _make_reported_user()
        mock_db.execute = AsyncMock(
            return_value=MagicMock(
                scalar_one_or_none=MagicMock(return_value=reported)
            )
        )

        async def _refresh(obj):
            obj.id = uuid4()
            obj.reporter_id = UUID(TEST_USER_ID)
            obj.reported_id = OTHER_USER_ID
            obj.reason = "fake_profile"
            obj.description = None
            obj.evidence_urls = None
            obj.is_block = True
            obj.status = "pending"
            obj.reviewed_by = None
            obj.reviewed_at = None
            obj.resolution = None
            obj.created_at = datetime.now(timezone.utc)

        mock_db.refresh = AsyncMock(side_effect=_refresh)
        mock_db.add = MagicMock()

        resp = await client.post(
            "/api/v1/reports",
            json={
                "reported_id": str(OTHER_USER_ID),
                "reason":      "fake_profile",
                "is_block":    True,
            },
        )

        assert resp.status_code == 201, resp.text
        assert resp.json()["is_block"] is True

    @pytest.mark.asyncio
    async def test_cannot_report_self(self, client, mock_db):
        """Self-reports must be rejected with 400."""
        resp = await client.post(
            "/api/v1/reports",
            json={
                "reported_id": TEST_USER_ID,   # same as authenticated user
                "reason":      "harassment",
            },
        )
        assert resp.status_code == 400
        assert "yourself" in resp.json()["detail"].lower()
        # No DB query should be needed for the self-check.
        mock_db.add.assert_not_called() if hasattr(mock_db.add, "assert_not_called") else None

    @pytest.mark.asyncio
    async def test_reported_user_not_found(self, client, mock_db):
        """If the reported user does not exist, 404."""
        mock_db.execute = AsyncMock(
            return_value=MagicMock(
                scalar_one_or_none=MagicMock(return_value=None)
            )
        )

        resp = await client.post(
            "/api/v1/reports",
            json={
                "reported_id": str(uuid4()),
                "reason":      "spam",
            },
        )
        assert resp.status_code == 404
        assert "not found" in resp.json()["detail"].lower()

    @pytest.mark.asyncio
    async def test_reported_user_deactivated(self, client, mock_db):
        """Deactivated users are treated like deleted users — 404."""
        reported = _make_reported_user(status=UserStatus.DEACTIVATED)
        mock_db.execute = AsyncMock(
            return_value=MagicMock(
                scalar_one_or_none=MagicMock(return_value=reported)
            )
        )

        resp = await client.post(
            "/api/v1/reports",
            json={
                "reported_id": str(OTHER_USER_ID),
                "reason":      "spam",
            },
        )
        assert resp.status_code == 404

    @pytest.mark.asyncio
    async def test_create_report_validation_short_reason(self, client):
        """Reason shorter than the schema minimum returns 422."""
        resp = await client.post(
            "/api/v1/reports",
            json={
                "reported_id": str(OTHER_USER_ID),
                "reason":      "a",   # below min_length=2
            },
        )
        assert resp.status_code == 422

    @pytest.mark.asyncio
    async def test_create_report_missing_reported_id(self, client):
        """Missing reported_id is a Pydantic validation error."""
        resp = await client.post(
            "/api/v1/reports",
            json={"reason": "harassment"},
        )
        assert resp.status_code == 422


# ─────────────────────────────────────────────
# GET /reports/me — LIST MY REPORTS
# ─────────────────────────────────────────────

class TestListMyReports:

    @pytest.mark.asyncio
    async def test_list_my_reports_returns_my_submissions(
        self, client, mock_db,
    ):
        """Returns the rows the DB layer hands back, serialised as ReportResponse."""
        rows = [
            _make_report_row(reason="harassment"),
            _make_report_row(reason="spam", is_block=True),
        ]

        result = MagicMock()
        result.scalars.return_value.all.return_value = rows
        mock_db.execute = AsyncMock(return_value=result)

        resp = await client.get("/api/v1/reports/me")

        assert resp.status_code == 200, resp.text
        body = resp.json()
        assert isinstance(body, list)
        assert len(body) == 2
        reasons = {r["reason"] for r in body}
        assert reasons == {"harassment", "spam"}
        assert any(r["is_block"] is True for r in body)

    @pytest.mark.asyncio
    async def test_list_my_reports_empty(self, client, mock_db):
        """No submissions yet → empty list, not 404."""
        result = MagicMock()
        result.scalars.return_value.all.return_value = []
        mock_db.execute = AsyncMock(return_value=result)

        resp = await client.get("/api/v1/reports/me")
        assert resp.status_code == 200
        assert resp.json() == []
