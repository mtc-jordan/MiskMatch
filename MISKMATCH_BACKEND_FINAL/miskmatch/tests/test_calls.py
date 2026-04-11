"""MiskMatch — Calls Router Tests"""

import pytest
from unittest.mock import MagicMock, AsyncMock, patch
from datetime import datetime, timezone, timedelta
from uuid import uuid4

from app.main import app
from app.core.database import get_db
from app.routers.auth import get_current_active_user
from app.models.models import Call, CallType, Match, MatchStatus, WaliRelationship

from tests.conftest import TEST_USER_ID, mock_db_result


# ── Helpers ──────────────────────────────────────────────────────

CALL_ID = uuid4()
MATCH_ID = uuid4()
OTHER_USER_ID = str(uuid4())


def _make_call(
    call_id=None,
    match_id=None,
    initiator_id=TEST_USER_ID,
    call_type=CallType.VIDEO_CHAPERONED,
    started_at=None,
    ended_at=None,
    duration_seconds=None,
    wali_approved=None,
):
    """Create a mock Call object."""
    call = MagicMock(spec=Call)
    call.id = call_id or CALL_ID
    call.match_id = match_id or MATCH_ID
    call.initiator_id = initiator_id
    call.call_type = call_type
    call.agora_channel = f"misk_{str(call.id).replace('-', '')[:20]}"
    call.wali_invited = True
    call.wali_joined = False
    call.wali_approved = wali_approved
    call.scheduled_at = None
    call.started_at = started_at
    call.ended_at = ended_at
    call.duration_seconds = duration_seconds
    return call


def _make_match(match_id=None, sender_id=TEST_USER_ID, receiver_id=None):
    """Create a mock Match object."""
    m = MagicMock(spec=Match)
    m.id = match_id or MATCH_ID
    m.sender_id = sender_id
    m.receiver_id = receiver_id or OTHER_USER_ID
    m.status = MatchStatus.ACTIVE
    m.sender_wali_approved = True
    m.receiver_wali_approved = True
    return m


@pytest.fixture(autouse=True)
def _override_deps(test_user, mock_db):
    """Override FastAPI dependencies for all tests in this module."""
    async def _fake_get_db():
        yield mock_db

    app.dependency_overrides[get_db] = _fake_get_db
    app.dependency_overrides[get_current_active_user] = lambda: test_user
    yield
    app.dependency_overrides.clear()


# ─────────────────────────────────────────────
# INITIATE CALL
# ─────────────────────────────────────────────

class TestInitiateCall:

    @pytest.mark.asyncio
    @patch("app.routers.calls.serialise_call")
    @patch("app.routers.calls.initiate_call")
    async def test_initiate_success(
        self, mock_initiate, mock_serialise,
        client, auth_headers,
    ):
        call = _make_call()
        token = MagicMock()
        mock_initiate.return_value = (call, token)
        mock_serialise.return_value = {
            "id": str(call.id), "match_id": str(call.match_id),
            "initiator_id": str(call.initiator_id),
            "call_type": "video_chaperoned", "agora_channel": call.agora_channel,
            "wali_invited": True, "wali_joined": False, "wali_approved": None,
            "scheduled_at": None, "started_at": None, "ended_at": None,
            "duration_seconds": None, "status": "ringing", "token": None,
        }

        resp = await client.post(
            "/api/v1/calls/initiate",
            json={"match_id": str(MATCH_ID), "call_type": "video_chaperoned"},
            headers=auth_headers,
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["call_type"] == "video_chaperoned"
        assert data["wali_invited"] is True
        mock_initiate.assert_called_once()

    @pytest.mark.asyncio
    @patch("app.routers.calls.initiate_call")
    async def test_initiate_service_error_returns_422(
        self, mock_initiate,
        client, auth_headers,
    ):
        mock_initiate.side_effect = ValueError("Match not found or not active.")

        resp = await client.post(
            "/api/v1/calls/initiate",
            json={"match_id": str(MATCH_ID), "call_type": "video_chaperoned"},
            headers=auth_headers,
        )
        assert resp.status_code == 422
        assert "Match not found" in resp.json()["detail"]


# ─────────────────────────────────────────────
# JOIN CALL
# ─────────────────────────────────────────────

class TestJoinCall:

    @pytest.mark.asyncio
    @patch("app.routers.calls.serialise_call")
    @patch("app.routers.calls.join_call")
    async def test_join_success(
        self, mock_join, mock_serialise,
        client, auth_headers,
    ):
        call = _make_call(started_at=datetime.now(timezone.utc))
        token = MagicMock()
        mock_join.return_value = (call, token)
        mock_serialise.return_value = {
            "id": str(call.id), "match_id": str(call.match_id),
            "initiator_id": str(call.initiator_id),
            "call_type": "video_chaperoned", "agora_channel": call.agora_channel,
            "wali_invited": True, "wali_joined": False, "wali_approved": None,
            "scheduled_at": None, "started_at": call.started_at.isoformat(),
            "ended_at": None, "duration_seconds": None,
            "status": "active", "token": None,
        }

        resp = await client.post(
            f"/api/v1/calls/{CALL_ID}/join",
            json={"participant_type": "receiver"},
            headers=auth_headers,
        )
        assert resp.status_code == 200
        mock_join.assert_called_once()

    @pytest.mark.asyncio
    @patch("app.routers.calls.join_call")
    async def test_join_service_error_returns_422(
        self, mock_join,
        client, auth_headers,
    ):
        mock_join.side_effect = ValueError("This call has already ended.")

        resp = await client.post(
            f"/api/v1/calls/{CALL_ID}/join",
            json={"participant_type": "receiver"},
            headers=auth_headers,
        )
        assert resp.status_code == 422
        assert "already ended" in resp.json()["detail"]


# ─────────────────────────────────────────────
# END CALL
# ─────────────────────────────────────────────

class TestEndCall:

    @pytest.mark.asyncio
    @patch("app.routers.calls.serialise_call")
    @patch("app.routers.calls.end_call")
    async def test_end_success(
        self, mock_end, mock_serialise,
        client, auth_headers,
    ):
        now = datetime.now(timezone.utc)
        call = _make_call(
            started_at=now - timedelta(minutes=15),
            ended_at=now,
            duration_seconds=900,
        )
        mock_end.return_value = call
        mock_serialise.return_value = {
            "id": str(call.id), "match_id": str(call.match_id),
            "initiator_id": str(call.initiator_id),
            "call_type": "video_chaperoned", "agora_channel": call.agora_channel,
            "wali_invited": True, "wali_joined": False, "wali_approved": None,
            "scheduled_at": None, "started_at": call.started_at.isoformat(),
            "ended_at": call.ended_at.isoformat(),
            "duration_seconds": 900, "status": "ended", "token": None,
        }

        resp = await client.post(
            f"/api/v1/calls/{CALL_ID}/end",
            json={"reason": "completed"},
            headers=auth_headers,
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["duration_seconds"] == 900
        assert data["status"] == "ended"
        mock_end.assert_called_once()

    @pytest.mark.asyncio
    @patch("app.routers.calls.end_call")
    async def test_end_service_error_returns_422(
        self, mock_end,
        client, auth_headers,
    ):
        mock_end.side_effect = ValueError("Call already ended.")

        resp = await client.post(
            f"/api/v1/calls/{CALL_ID}/end",
            json={"reason": "completed"},
            headers=auth_headers,
        )
        assert resp.status_code == 422
        assert "already ended" in resp.json()["detail"]


# ─────────────────────────────────────────────
# GET CALL DETAILS
# ─────────────────────────────────────────────

class TestGetCallDetails:

    @pytest.mark.asyncio
    @patch("app.routers.calls.serialise_call")
    async def test_get_call_success(
        self, mock_serialise,
        client, auth_headers, mock_db,
    ):
        call = _make_call()
        match = _make_match()

        # First execute: Call lookup; second: Match participant check
        mock_db.execute = AsyncMock(
            side_effect=[
                mock_db_result(scalar_value=call),
                mock_db_result(scalar_value=match),
            ]
        )

        mock_serialise.return_value = {
            "id": str(call.id), "match_id": str(call.match_id),
            "initiator_id": str(call.initiator_id),
            "call_type": "video_chaperoned", "agora_channel": call.agora_channel,
            "wali_invited": True, "wali_joined": False, "wali_approved": None,
            "scheduled_at": None, "started_at": None, "ended_at": None,
            "duration_seconds": None, "status": "ringing", "token": None,
        }

        resp = await client.get(
            f"/api/v1/calls/{CALL_ID}",
            headers=auth_headers,
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["id"] == str(call.id)

    @pytest.mark.asyncio
    async def test_get_call_not_found(
        self, client, auth_headers, mock_db,
    ):
        mock_db.execute = AsyncMock(return_value=mock_db_result(scalar_value=None))

        resp = await client.get(
            f"/api/v1/calls/{CALL_ID}",
            headers=auth_headers,
        )
        assert resp.status_code == 404
        assert "not found" in resp.json()["detail"].lower()

    @pytest.mark.asyncio
    async def test_get_call_not_participant_returns_403(
        self, client, auth_headers, mock_db,
    ):
        call = _make_call()

        # Call found, but match participant check returns None
        mock_db.execute = AsyncMock(
            side_effect=[
                mock_db_result(scalar_value=call),
                mock_db_result(scalar_value=None),
            ]
        )

        resp = await client.get(
            f"/api/v1/calls/{CALL_ID}",
            headers=auth_headers,
        )
        assert resp.status_code == 403
        assert "not a participant" in resp.json()["detail"].lower()


# ─────────────────────────────────────────────
# CALL HISTORY
# ─────────────────────────────────────────────

class TestCallHistory:

    @pytest.mark.asyncio
    @patch("app.routers.calls.call_status")
    @patch("app.routers.calls.get_call_history")
    async def test_call_history_success(
        self, mock_history, mock_status,
        client, auth_headers, mock_db,
    ):
        match = _make_match()
        mock_db.execute = AsyncMock(return_value=mock_db_result(scalar_value=match))

        call1 = _make_call(call_id=uuid4())
        call1.scheduled_at = None
        call1.started_at = datetime.now(timezone.utc) - timedelta(hours=1)
        call1.duration_seconds = 600

        mock_history.return_value = ([call1], 1)
        mock_status.return_value = "ended"

        resp = await client.get(
            f"/api/v1/calls/match/{MATCH_ID}",
            headers=auth_headers,
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["total"] == 1
        assert len(data["calls"]) == 1

    @pytest.mark.asyncio
    async def test_call_history_not_in_match_returns_403(
        self, client, auth_headers, mock_db,
    ):
        # Match not found or user not participant
        mock_db.execute = AsyncMock(return_value=mock_db_result(scalar_value=None))

        resp = await client.get(
            f"/api/v1/calls/match/{MATCH_ID}",
            headers=auth_headers,
        )
        assert resp.status_code == 403
        assert "access denied" in resp.json()["detail"].lower()


# ─────────────────────────────────────────────
# ACTIVE CALL
# ─────────────────────────────────────────────

class TestActiveCall:

    @pytest.mark.asyncio
    @patch("app.routers.calls.serialise_call")
    async def test_active_call_exists(
        self, mock_serialise,
        client, auth_headers, mock_db,
    ):
        call = _make_call(started_at=datetime.now(timezone.utc))
        mock_db.execute = AsyncMock(return_value=mock_db_result(scalar_value=call))

        mock_serialise.return_value = {
            "id": str(call.id), "match_id": str(call.match_id),
            "initiator_id": str(call.initiator_id),
            "call_type": "video_chaperoned", "agora_channel": call.agora_channel,
            "wali_invited": True, "wali_joined": False, "wali_approved": None,
            "scheduled_at": None, "started_at": call.started_at.isoformat(),
            "ended_at": None, "duration_seconds": None,
            "status": "active", "token": None,
        }

        resp = await client.get(
            "/api/v1/calls/active",
            headers=auth_headers,
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["status"] == "active"

    @pytest.mark.asyncio
    async def test_no_active_call_returns_null(
        self, client, auth_headers, mock_db,
    ):
        mock_db.execute = AsyncMock(return_value=mock_db_result(scalar_value=None))

        resp = await client.get(
            "/api/v1/calls/active",
            headers=auth_headers,
        )
        assert resp.status_code == 200
        assert resp.json() is None


# ─────────────────────────────────────────────
# WALI APPROVE
# ─────────────────────────────────────────────

class TestWaliApprove:

    @pytest.mark.asyncio
    async def test_wali_approve_success(
        self, client, auth_headers, mock_db,
    ):
        call = _make_call()
        match = _make_match()
        wali_rel = MagicMock(spec=WaliRelationship)
        wali_rel.wali_user_id = TEST_USER_ID
        wali_rel.is_active = True

        # Three DB calls: call lookup, match lookup, wali check
        mock_db.execute = AsyncMock(
            side_effect=[
                mock_db_result(scalar_value=call),
                mock_db_result(scalar_value=match),
                mock_db_result(scalar_value=wali_rel),
            ]
        )
        mock_db.commit = AsyncMock()

        resp = await client.post(
            f"/api/v1/calls/{CALL_ID}/wali-approve?approved=true",
            headers=auth_headers,
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["approved"] is True
        assert "JazakAllah" in data["message"]

    @pytest.mark.asyncio
    async def test_wali_approve_call_not_found(
        self, client, auth_headers, mock_db,
    ):
        mock_db.execute = AsyncMock(return_value=mock_db_result(scalar_value=None))

        resp = await client.post(
            f"/api/v1/calls/{CALL_ID}/wali-approve?approved=true",
            headers=auth_headers,
        )
        assert resp.status_code == 404
        assert "not found" in resp.json()["detail"].lower()

    @pytest.mark.asyncio
    async def test_wali_approve_not_a_wali_returns_403(
        self, client, auth_headers, mock_db,
    ):
        call = _make_call()
        match = _make_match()

        # Call found, match found, but wali check returns None
        mock_db.execute = AsyncMock(
            side_effect=[
                mock_db_result(scalar_value=call),
                mock_db_result(scalar_value=match),
                mock_db_result(scalar_value=None),
            ]
        )

        resp = await client.post(
            f"/api/v1/calls/{CALL_ID}/wali-approve?approved=true",
            headers=auth_headers,
        )
        assert resp.status_code == 403
        assert "guardian" in resp.json()["detail"].lower()

    @pytest.mark.asyncio
    async def test_wali_decline_message(
        self, client, auth_headers, mock_db,
    ):
        call = _make_call()
        match = _make_match()
        wali_rel = MagicMock(spec=WaliRelationship)
        wali_rel.wali_user_id = TEST_USER_ID
        wali_rel.is_active = True

        mock_db.execute = AsyncMock(
            side_effect=[
                mock_db_result(scalar_value=call),
                mock_db_result(scalar_value=match),
                mock_db_result(scalar_value=wali_rel),
            ]
        )
        mock_db.commit = AsyncMock()

        resp = await client.post(
            f"/api/v1/calls/{CALL_ID}/wali-approve?approved=false",
            headers=auth_headers,
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["approved"] is False
        assert "declined" in data["message"].lower()


# ─────────────────────────────────────────────
# ROUTER STRUCTURE
# ─────────────────────────────────────────────

class TestCallsRouter:

    def test_router_has_all_endpoints(self):
        from app.routers.calls import router
        paths = {r.path for r in router.routes if hasattr(r, "path")}

        assert "/calls/initiate"              in paths
        assert "/calls/{call_id}/join"        in paths
        assert "/calls/{call_id}/end"         in paths
        assert "/calls/{call_id}"             in paths
        assert "/calls/match/{match_id}"      in paths
        assert "/calls/active"                in paths
        assert "/calls/{call_id}/wali-approve" in paths

    def test_total_route_count(self):
        from app.routers.calls import router
        assert len(router.routes) == 7

    def test_router_prefix(self):
        from app.routers.calls import router
        assert router.prefix == "/calls"

    def test_router_tag(self):
        from app.routers.calls import router
        assert "Call" in router.tags[0]


# ─────────────────────────────────────────────
# CALLS SERVICE UNIT TESTS
# ─────────────────────────────────────────────

class TestCallServiceHelpers:

    def test_make_channel_name_format(self):
        from app.services.calls import make_channel_name
        import uuid
        call_id = uuid.uuid4()
        channel = make_channel_name(call_id)
        assert channel.startswith("misk_")
        assert len(channel) == 25  # "misk_" + 20 chars

    def test_make_channel_name_unique(self):
        from app.services.calls import make_channel_name
        import uuid
        c1 = make_channel_name(uuid.uuid4())
        c2 = make_channel_name(uuid.uuid4())
        assert c1 != c2

    def test_call_status_ended_with_duration(self):
        from app.services.calls import call_status
        call = _make_call(
            started_at=datetime.now(timezone.utc) - timedelta(minutes=10),
            ended_at=datetime.now(timezone.utc),
            duration_seconds=600,
        )
        assert call_status(call) == "ended"

    def test_call_status_missed(self):
        from app.services.calls import call_status
        call = _make_call(
            started_at=None,
            ended_at=datetime.now(timezone.utc),
            duration_seconds=0,
        )
        assert call_status(call) == "missed"

    def test_call_status_active(self):
        from app.services.calls import call_status
        call = _make_call(
            started_at=datetime.now(timezone.utc) - timedelta(minutes=5),
            ended_at=None,
        )
        assert call_status(call) == "active"

    def test_call_status_ringing(self):
        from app.services.calls import call_status
        call = _make_call(started_at=None, ended_at=None)
        call.scheduled_at = None
        assert call_status(call) == "ringing"

    def test_call_status_scheduled(self):
        from app.services.calls import call_status
        call = _make_call(started_at=None, ended_at=None)
        call.scheduled_at = datetime.now(timezone.utc) + timedelta(hours=1)
        assert call_status(call) == "scheduled"

    def test_dev_token_deterministic(self):
        from app.services.calls import _dev_token
        t1 = _dev_token("channel1", 123)
        t2 = _dev_token("channel1", 123)
        assert t1 == t2
        assert t1.startswith("dev_token_")

    def test_dev_token_different_inputs(self):
        from app.services.calls import _dev_token
        t1 = _dev_token("channel1", 123)
        t2 = _dev_token("channel2", 456)
        assert t1 != t2

    def test_generate_agora_token_dev_mode(self):
        from app.services.calls import generate_agora_token
        with patch("app.services.calls.settings") as mock_settings:
            mock_settings.AGORA_APP_ID = ""
            mock_settings.AGORA_APP_CERT = ""
            mock_settings.is_production = False
            token = generate_agora_token("test_channel", 1)
            assert token.startswith("dev_token_")

    def test_serialise_call_all_fields(self):
        from app.services.calls import serialise_call
        call = _make_call(
            started_at=datetime.now(timezone.utc),
            ended_at=None,
        )
        result = serialise_call(call)
        assert result.id == call.id
        assert result.match_id == call.match_id
        assert result.status == "active"
        assert result.token is None

    def test_serialise_call_ended(self):
        from app.services.calls import serialise_call
        call = _make_call(
            started_at=datetime.now(timezone.utc) - timedelta(minutes=5),
            ended_at=datetime.now(timezone.utc),
            duration_seconds=300,
        )
        result = serialise_call(call)
        assert result.status == "ended"
        assert result.duration_seconds == 300
