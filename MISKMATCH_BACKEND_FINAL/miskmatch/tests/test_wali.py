"""MiskMatch — Wali System Tests"""

import pytest
from datetime import datetime, timezone, timedelta
from unittest.mock import AsyncMock, MagicMock
from uuid import uuid4

from app.models.models import WaliRelationship, Match, MatchStatus
from app.schemas.wali import (
    WaliSetupRequest, WaliUpdatePermissionsRequest,
    WaliMatchDecisionRequest, WaliInviteResponse,
)


# ─────────────────────────────────────────────
# SCHEMA VALIDATION TESTS
# ─────────────────────────────────────────────

class TestWaliSchemas:

    def test_valid_setup_request(self):
        req = WaliSetupRequest(
            wali_name="Ahmad Al-Rashidi",
            wali_phone="+962791234567",
            wali_relationship="father",
        )
        assert req.wali_name == "Ahmad Al-Rashidi"
        assert req.wali_relationship == "father"

    def test_name_whitespace_stripped(self):
        req = WaliSetupRequest(
            wali_name="  Ahmad Al-Rashidi  ",
            wali_phone="+962791234567",
            wali_relationship="father",
        )
        assert req.wali_name == "Ahmad Al-Rashidi"

    def test_invalid_phone_format(self):
        from pydantic import ValidationError
        with pytest.raises(ValidationError, match="E.164"):
            WaliSetupRequest(
                wali_name="Ahmad",
                wali_phone="0791234567",  # missing +country code
                wali_relationship="father",
            )

    def test_phone_without_plus_rejected(self):
        from pydantic import ValidationError
        with pytest.raises(ValidationError):
            WaliSetupRequest(
                wali_name="Ahmad",
                wali_phone="962791234567",
                wali_relationship="father",
            )

    def test_invalid_relationship_rejected(self):
        from pydantic import ValidationError
        with pytest.raises(ValidationError, match="Invalid relationship"):
            WaliSetupRequest(
                wali_name="Ahmad",
                wali_phone="+962791234567",
                wali_relationship="friend",  # not a valid Islamic wali
            )

    def test_all_valid_relationships(self):
        valid = [
            "father", "brother", "uncle", "grandfather",
            "male_relative", "imam", "trusted_male_guardian",
        ]
        for rel in valid:
            req = WaliSetupRequest(
                wali_name="Test Wali",
                wali_phone="+962791234567",
                wali_relationship=rel,
            )
            assert req.wali_relationship == rel

    def test_relationship_normalized_lowercase(self):
        req = WaliSetupRequest(
            wali_name="Ahmad",
            wali_phone="+962791234567",
            wali_relationship="FATHER",
        )
        assert req.wali_relationship == "father"

    def test_decision_request_approve(self):
        req = WaliMatchDecisionRequest(decision="approve", note="May Allah bless them.")
        assert req.decision == "approve"

    def test_decision_request_decline(self):
        req = WaliMatchDecisionRequest(decision="decline", note="Not compatible.")
        assert req.decision == "decline"

    def test_decision_invalid(self):
        from pydantic import ValidationError
        with pytest.raises(ValidationError):
            WaliMatchDecisionRequest(decision="maybe")

    def test_permissions_update_partial(self):
        req = WaliUpdatePermissionsRequest(can_view_messages=True)
        assert req.can_view_messages is True
        assert req.can_view_matches is None    # not set — no change
        assert req.can_join_calls is None      # not set — no change

    def test_permissions_all_false(self):
        req = WaliUpdatePermissionsRequest(
            can_view_messages=False,
            can_view_matches=False,
            can_join_calls=False,
        )
        assert req.can_view_messages is False


# ─────────────────────────────────────────────
# SERVICE LOGIC TESTS
# ─────────────────────────────────────────────

class TestWaliService:

    def _make_db(self, return_value=None):
        db = AsyncMock()
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = return_value
        mock_result.scalar.return_value = 0
        mock_result.scalars.return_value.all.return_value = []
        mock_result.fetchall.return_value = []
        mock_result.one.return_value = MagicMock(total=0, flagged=0)
        db.execute = AsyncMock(return_value=mock_result)
        db.flush = AsyncMock()
        db.add = MagicMock()
        return db

    def _make_wali_rel(
        self, ward_id=None, wali_user_id=None,
        accepted=True, active=True, sent=True,
    ) -> WaliRelationship:
        rel = MagicMock(spec=WaliRelationship)
        rel.id                   = uuid4()
        rel.user_id              = ward_id or uuid4()
        rel.wali_user_id         = wali_user_id or uuid4()
        rel.wali_name            = "Ahmad Al-Rashidi"
        rel.wali_phone           = "+962791234567"
        rel.wali_relationship    = "father"
        rel.is_active            = active
        rel.invitation_sent      = sent
        rel.invitation_accepted  = accepted
        rel.invited_at           = datetime.now(timezone.utc) - timedelta(hours=1)
        rel.accepted_at          = datetime.now(timezone.utc) if accepted else None
        rel.can_view_matches     = True
        rel.can_view_messages    = False
        rel.can_approve_matches  = True
        rel.can_join_calls       = True
        rel.created_at           = datetime.now(timezone.utc)
        rel.updated_at           = datetime.now(timezone.utc) - timedelta(days=31)
        return rel

    @pytest.mark.asyncio
    async def test_setup_wali_no_existing(self):
        from app.services.wali import setup_wali

        ward_id = uuid4()
        db = self._make_db(return_value=None)  # no existing wali

        # Mock user lookup
        mock_user = MagicMock()
        mock_user.id = ward_id
        call_count = [0]
        async def mock_execute(*args, **kwargs):
            call_count[0] += 1
            r = MagicMock()
            if call_count[0] == 1:
                r.scalar_one_or_none.return_value = mock_user  # user found
            else:
                r.scalar_one_or_none.return_value = None        # no existing wali, no wali_user match
            return r
        db.execute = mock_execute

        req = WaliSetupRequest(
            wali_name="Ahmad Al-Rashidi",
            wali_phone="+962791234567",
            wali_relationship="father",
        )
        wali_rel = await setup_wali(db, ward_id, req)
        assert db.add.called
        assert db.flush.called

    @pytest.mark.asyncio
    async def test_setup_wali_cooldown_enforced(self):
        from app.services.wali import setup_wali

        ward_id = uuid4()
        existing = self._make_wali_rel(ward_id=ward_id)
        existing.updated_at = datetime.now(timezone.utc) - timedelta(days=5)  # 5 days ago

        mock_user = MagicMock(); mock_user.id = ward_id
        call_count = [0]
        async def mock_execute(*args, **kwargs):
            call_count[0] += 1
            r = MagicMock()
            if call_count[0] == 1:
                r.scalar_one_or_none.return_value = mock_user
            else:
                r.scalar_one_or_none.return_value = existing
            return r
        db = self._make_db()
        db.execute = mock_execute
        db.flush = AsyncMock()
        db.add = MagicMock()

        req = WaliSetupRequest(
            wali_name="New Wali",
            wali_phone="+962791111111",
            wali_relationship="brother",
        )
        with pytest.raises(ValueError, match="30 days"):
            await setup_wali(db, ward_id, req)

    @pytest.mark.asyncio
    async def test_send_invitation_no_wali_fails(self):
        from app.services.wali import send_wali_invitation

        db = self._make_db(return_value=None)
        with pytest.raises(ValueError, match="No wali registered"):
            await send_wali_invitation(db, uuid4())

    @pytest.mark.asyncio
    async def test_send_invitation_already_accepted_fails(self):
        from app.services.wali import send_wali_invitation

        wali_rel = self._make_wali_rel(accepted=True)
        db = self._make_db(return_value=wali_rel)
        with pytest.raises(ValueError, match="already accepted"):
            await send_wali_invitation(db, uuid4())

    @pytest.mark.asyncio
    async def test_accept_expired_invitation_fails(self):
        from app.services.wali import accept_wali_invitation

        ward_id  = uuid4()
        wali_rel = self._make_wali_rel(ward_id=ward_id, accepted=False)
        # Expired: invited 73 hours ago
        wali_rel.invited_at = datetime.now(timezone.utc) - timedelta(hours=73)

        db = self._make_db(return_value=wali_rel)
        with pytest.raises(ValueError, match="expired"):
            await accept_wali_invitation(db, "+962791234567", ward_id)

    @pytest.mark.asyncio
    async def test_accept_no_pending_invitation_fails(self):
        from app.services.wali import accept_wali_invitation

        db = self._make_db(return_value=None)
        with pytest.raises(ValueError, match="No pending invitation"):
            await accept_wali_invitation(db, "+962799999999", uuid4())

    @pytest.mark.asyncio
    async def test_remove_wali_with_pending_match_fails(self):
        from app.services.wali import remove_wali

        ward_id  = uuid4()
        wali_rel = self._make_wali_rel(ward_id=ward_id)

        call_count = [0]
        async def mock_execute(*args, **kwargs):
            call_count[0] += 1
            r = MagicMock()
            if call_count[0] == 1:
                r.scalar_one_or_none.return_value = wali_rel  # active wali found
            else:
                r.scalar.return_value = 2   # 2 pending matches
            return r

        db = self._make_db()
        db.execute = mock_execute
        db.flush = AsyncMock()

        with pytest.raises(ValueError, match="awaiting"):
            await remove_wali(db, ward_id, "test reason")

    @pytest.mark.asyncio
    async def test_decide_match_not_found(self):
        from app.services.wali import decide_match

        db = self._make_db(return_value=None)  # match not found
        with pytest.raises(ValueError, match="not found"):
            await decide_match(db, uuid4(), uuid4(), "approve", None)

    @pytest.mark.asyncio
    async def test_decide_match_wrong_status_fails(self):
        from app.services.wali import decide_match, _resolve_ward_in_match

        match = MagicMock(spec=Match)
        match.id          = uuid4()
        match.sender_id   = uuid4()
        match.receiver_id = uuid4()
        match.status      = MatchStatus.ACTIVE   # already active — can't decide

        wali_user_id = uuid4()
        db = self._make_db(return_value=match)

        # Patch _resolve_ward_in_match to return a ward
        import app.services.wali as svc
        original = svc._resolve_ward_in_match
        async def fake_resolve(db, wali_id, m):
            return m.sender_id
        svc._resolve_ward_in_match = fake_resolve

        try:
            with pytest.raises(ValueError, match="cannot be decided"):
                await decide_match(db, wali_user_id, match.id, "approve", None)
        finally:
            svc._resolve_ward_in_match = original

    @pytest.mark.asyncio
    async def test_get_ward_wali_status_no_wali(self):
        from app.services.wali import get_ward_wali_status

        db = self._make_db(return_value=None)
        result = await get_ward_wali_status(db, uuid4())

        assert result["has_wali"] is False
        assert result["invitation_sent"] is False
        assert result["invitation_accepted"] is False

    @pytest.mark.asyncio
    async def test_get_ward_wali_status_with_wali(self):
        from app.services.wali import get_ward_wali_status

        ward_id  = uuid4()
        wali_rel = self._make_wali_rel(ward_id=ward_id, accepted=True)
        db = self._make_db(return_value=wali_rel)

        result = await get_ward_wali_status(db, ward_id)
        assert result["has_wali"] is True
        assert result["invitation_accepted"] is True
        assert result["wali_name"] == "Ahmad Al-Rashidi"

    @pytest.mark.asyncio
    async def test_update_permissions_no_wali_fails(self):
        from app.services.wali import update_wali_permissions

        db = self._make_db(return_value=None)
        req = WaliUpdatePermissionsRequest(can_view_messages=True)
        with pytest.raises(ValueError, match="No active wali"):
            await update_wali_permissions(db, uuid4(), req)

    @pytest.mark.asyncio
    async def test_resolve_ward_in_match_returns_none_if_not_authorised(self):
        from app.services.wali import _resolve_ward_in_match

        match = MagicMock(spec=Match)
        match.sender_id   = uuid4()
        match.receiver_id = uuid4()

        # Wali has no relationship to either participant
        db = self._make_db(return_value=None)
        result = await _resolve_ward_in_match(db, uuid4(), match)
        assert result is None


# ─────────────────────────────────────────────
# ROUTER TESTS
# ─────────────────────────────────────────────

class TestWaliRouter:

    def test_router_has_all_endpoints(self):
        from app.routers.wali import router
        paths = {r.path for r in router.routes if hasattr(r, "path")}

        assert "/wali/setup"                    in paths
        assert "/wali/invite"                   in paths
        assert "/wali/invite/resend"            in paths
        assert "/wali/accept"                   in paths
        assert "/wali/status"                   in paths
        assert "/wali/permissions"              in paths
        assert "/wali"                          in paths   # DELETE
        assert "/wali/dashboard"                in paths
        assert "/wali/wards"                    in paths
        assert "/wali/decisions/pending"        in paths
        assert "/wali/matches/{match_id}"       in paths
        assert "/wali/matches/{match_id}/decide" in paths

    def test_total_route_count(self):
        from app.routers.wali import router
        # 12 endpoints (7 ward + 5 wali)
        assert len(router.routes) == 12

    def test_router_prefix(self):
        from app.routers.wali import router
        assert router.prefix == "/wali"

    def test_router_tag(self):
        from app.routers.wali import router
        assert "Wali" in router.tags[0]


# ─────────────────────────────────────────────
# HTTP ENDPOINT TESTS
# ─────────────────────────────────────────────

from unittest.mock import patch
from app.core.database import get_db
from app.routers.auth import get_current_active_user
from tests.conftest import TEST_USER_ID


@pytest.fixture(autouse=True, scope="class")
def _override_wali_deps(test_user, mock_db):
    from app.main import app

    async def _fake_get_db():
        yield mock_db

    app.dependency_overrides[get_db] = _fake_get_db
    app.dependency_overrides[get_current_active_user] = lambda: test_user
    yield
    app.dependency_overrides.clear()


class TestWaliHTTP:

    @pytest.mark.asyncio
    @patch("app.services.wali.setup_wali")
    async def test_setup_wali(self, mock_svc, client, mock_db):
        rel = MagicMock()
        rel.wali_name = "Ahmad Al-Rashidi"
        rel.wali_phone = "+962791234567"
        rel.wali_relationship = "father"
        mock_svc.return_value = rel
        resp = await client.post("/api/v1/wali/setup", json={
            "wali_name": "Ahmad Al-Rashidi",
            "wali_phone": "+962791234567",
            "wali_relationship": "father",
        })
        assert resp.status_code == 201
        assert "Wali registered" in resp.json()["message"]

    @pytest.mark.asyncio
    @patch("app.services.wali.setup_wali")
    async def test_setup_wali_invalid_relationship(self, mock_svc, client):
        resp = await client.post("/api/v1/wali/setup", json={
            "wali_name": "Ahmad",
            "wali_phone": "+962791234567",
            "wali_relationship": "friend",  # invalid
        })
        assert resp.status_code == 422

    @pytest.mark.asyncio
    @patch("app.services.wali.setup_wali")
    async def test_setup_wali_cooldown(self, mock_svc, client):
        mock_svc.side_effect = ValueError("You can only change your wali once every 30 days.")
        resp = await client.post("/api/v1/wali/setup", json={
            "wali_name": "New Wali",
            "wali_phone": "+962791111111",
            "wali_relationship": "brother",
        })
        assert resp.status_code == 422

    @pytest.mark.asyncio
    @patch("app.services.wali.send_wali_invitation")
    async def test_send_invitation(self, mock_svc, client, mock_db):
        mock_svc.return_value = WaliInviteResponse(
            invitation_sent=True,
            wali_name="Ahmad",
            wali_phone="+962791234567",
            message="Invitation sent.",
        )
        resp = await client.post("/api/v1/wali/invite")
        assert resp.status_code == 200
        assert resp.json()["invitation_sent"] is True

    @pytest.mark.asyncio
    @patch("app.services.wali.send_wali_invitation")
    async def test_send_invitation_no_wali(self, mock_svc, client):
        mock_svc.side_effect = ValueError("No wali registered.")
        resp = await client.post("/api/v1/wali/invite")
        assert resp.status_code == 422

    @pytest.mark.asyncio
    @patch("app.services.wali.get_ward_wali_status")
    async def test_get_wali_status(self, mock_svc, client):
        mock_svc.return_value = {
            "has_wali": True,
            "wali_name": "Ahmad",
            "wali_phone": "+962791234567",
            "wali_relationship": "father",
            "wali_user_id": None,
            "is_active": True,
            "invitation_sent": True,
            "invitation_accepted": True,
            "invited_at": "2026-01-01T00:00:00Z",
            "accepted_at": "2026-01-02T00:00:00Z",
            "can_view_matches": True,
            "can_view_messages": False,
            "can_approve_matches": True,
            "can_join_calls": True,
        }
        resp = await client.get("/api/v1/wali/status")
        assert resp.status_code == 200
        assert resp.json()["has_wali"] is True

    @pytest.mark.asyncio
    @patch("app.services.wali.update_wali_permissions")
    async def test_update_permissions(self, mock_svc, client, mock_db):
        rel = MagicMock()
        rel.can_view_matches = True
        rel.can_view_messages = True
        rel.can_approve_matches = True
        rel.can_join_calls = False
        mock_svc.return_value = rel
        resp = await client.put("/api/v1/wali/permissions", json={
            "can_view_messages": True,
            "can_join_calls": False,
        })
        assert resp.status_code == 200
        perms = resp.json()["permissions"]
        assert perms["can_view_messages"] is True
        assert perms["can_join_calls"] is False

    @pytest.mark.asyncio
    @patch("app.services.wali.remove_wali")
    async def test_remove_wali(self, mock_svc, client, mock_db):
        mock_svc.return_value = {"message": "Wali removed."}
        resp = await client.delete("/api/v1/wali?reason=Personal+reasons+for+removal")
        assert resp.status_code == 200

    @pytest.mark.asyncio
    @patch("app.services.wali.remove_wali")
    async def test_remove_wali_pending_match(self, mock_svc, client):
        mock_svc.side_effect = ValueError("Cannot remove wali while matches are awaiting approval.")
        resp = await client.delete("/api/v1/wali?reason=Just+a+test+reason+here")
        assert resp.status_code == 422

    @pytest.mark.asyncio
    @patch("app.services.wali.get_wali_dashboard")
    async def test_wali_dashboard(self, mock_svc, client):
        mock_svc.return_value = {
            "wali_user_id": TEST_USER_ID,
            "total_wards": 2,
            "pending_decisions": 1,
            "active_matches": 3,
            "flagged_messages": 0,
            "wards": [],
            "pending_match_decisions": [],
            "recent_notifications": [],
        }
        resp = await client.get("/api/v1/wali/dashboard")
        assert resp.status_code == 200
        assert resp.json()["total_wards"] == 2

    @pytest.mark.asyncio
    @patch("app.services.wali.get_wali_wards")
    async def test_get_wards(self, mock_svc, client):
        mock_svc.return_value = [{"user_id": str(uuid4()), "name": "Sara"}]
        resp = await client.get("/api/v1/wali/wards")
        assert resp.status_code == 200
        assert resp.json()["total"] == 1

    @pytest.mark.asyncio
    @patch("app.services.wali.get_pending_decisions")
    async def test_pending_decisions(self, mock_svc, client):
        mock_svc.return_value = []
        resp = await client.get("/api/v1/wali/decisions/pending")
        assert resp.status_code == 200
        assert resp.json()["total_pending"] == 0

    @pytest.mark.asyncio
    @patch("app.services.wali.get_match_summary_for_wali")
    async def test_match_summary(self, mock_svc, client):
        mock_svc.return_value = {"match_id": str(uuid4()), "status": "mutual"}
        resp = await client.get(f"/api/v1/wali/matches/{uuid4()}")
        assert resp.status_code == 200

    @pytest.mark.asyncio
    @patch("app.services.wali.get_match_summary_for_wali")
    async def test_match_summary_forbidden(self, mock_svc, client):
        mock_svc.side_effect = ValueError("Not authorized for this match.")
        resp = await client.get(f"/api/v1/wali/matches/{uuid4()}")
        assert resp.status_code == 403

    @pytest.mark.asyncio
    @patch("app.services.wali.decide_match")
    async def test_decide_match_approve(self, mock_svc, client, mock_db):
        mock_svc.return_value = {"decision": "approved", "match_status": "approved"}
        resp = await client.post(
            f"/api/v1/wali/matches/{uuid4()}/decide",
            json={"decision": "approve", "note": "May Allah bless this union."},
        )
        assert resp.status_code == 200

    @pytest.mark.asyncio
    @patch("app.services.wali.decide_match")
    async def test_decide_match_decline(self, mock_svc, client, mock_db):
        mock_svc.return_value = {"decision": "declined", "match_status": "closed"}
        resp = await client.post(
            f"/api/v1/wali/matches/{uuid4()}/decide",
            json={"decision": "decline", "note": "Not compatible for my ward."},
        )
        assert resp.status_code == 200

    @pytest.mark.asyncio
    async def test_decide_invalid_decision(self, client):
        resp = await client.post(
            f"/api/v1/wali/matches/{uuid4()}/decide",
            json={"decision": "maybe"},
        )
        assert resp.status_code == 422
