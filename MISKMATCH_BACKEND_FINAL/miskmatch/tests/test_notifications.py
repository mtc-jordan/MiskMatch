"""
MiskMatch — Notification Service Tests
Tests for SMS (Twilio) and Push (Firebase) notification functions.
"""

import pytest
from unittest.mock import AsyncMock, MagicMock, patch, PropertyMock

from tests.conftest import mock_db_result


# ─────────────────────────────────────────────
# SMS — send_sms
# ─────────────────────────────────────────────


class TestSendSms:
    """Tests for send_sms()."""

    @pytest.mark.anyio
    @patch("app.services.notifications.settings")
    async def test_send_sms_dev_mode(self, mock_settings):
        """In development mode, logs the message and returns True without calling Twilio."""
        mock_settings.is_development = True

        from app.services.notifications import send_sms

        result = await send_sms("+962791234567", "Hello test")
        assert result is True

    @pytest.mark.anyio
    @patch("app.services.notifications.settings")
    async def test_send_sms_no_credentials(self, mock_settings):
        """Returns False when Twilio SID is empty."""
        mock_settings.is_development = False
        mock_settings.TWILIO_ACCOUNT_SID = ""
        mock_settings.TWILIO_AUTH_TOKEN = ""

        from app.services.notifications import send_sms

        result = await send_sms("+962791234567", "Hello test")
        assert result is False

    @pytest.mark.anyio
    @patch("app.services.notifications.settings")
    async def test_send_sms_success(self, mock_settings):
        """Successful Twilio call returns True."""
        mock_settings.is_development = False
        mock_settings.TWILIO_ACCOUNT_SID = "AC_test_sid"
        mock_settings.TWILIO_AUTH_TOKEN = "test_auth_token"
        mock_settings.TWILIO_PHONE = "+15551234567"

        mock_client_instance = MagicMock()
        mock_client_instance.messages.create.return_value = MagicMock(sid="SM123")

        with patch("app.services.notifications.asyncio.to_thread", new_callable=AsyncMock) as mock_thread:
            mock_thread.return_value = MagicMock(sid="SM123")

            from app.services.notifications import send_sms

            result = await send_sms("+962791234567", "Hello test")

        assert result is True
        mock_thread.assert_awaited_once()

    @pytest.mark.anyio
    @patch("app.services.notifications.settings")
    async def test_send_sms_failure(self, mock_settings):
        """Twilio exception returns False."""
        mock_settings.is_development = False
        mock_settings.TWILIO_ACCOUNT_SID = "AC_test_sid"
        mock_settings.TWILIO_AUTH_TOKEN = "test_auth_token"
        mock_settings.TWILIO_PHONE = "+15551234567"

        with patch("app.services.notifications.asyncio.to_thread", new_callable=AsyncMock) as mock_thread:
            mock_thread.side_effect = Exception("Twilio connection failed")

            from app.services.notifications import send_sms

            result = await send_sms("+962791234567", "Hello test")

        assert result is False


# ─────────────────────────────────────────────
# Push — send_push_notification
# ─────────────────────────────────────────────


class TestSendPush:
    """Tests for send_push_notification()."""

    @pytest.mark.anyio
    async def test_push_empty_token(self):
        """Empty FCM token returns False immediately."""
        from app.services.notifications import send_push_notification

        result = await send_push_notification("", "Title", "Body")
        assert result is False

    @pytest.mark.anyio
    @patch("app.services.notifications.settings")
    async def test_push_dev_mode(self, mock_settings):
        """In dev mode with no Firebase configured, logs and returns True."""
        mock_settings.is_development = True
        mock_settings.FIREBASE_CREDENTIALS_PATH = ""

        from app.services.notifications import send_push_notification

        result = await send_push_notification("some-token", "Title", "Body")
        assert result is True

    @pytest.mark.anyio
    @patch("app.services.notifications._get_firebase_app")
    @patch("app.services.notifications.settings")
    async def test_push_success(self, mock_settings, mock_get_app):
        """Successful Firebase send returns True."""
        mock_settings.is_development = False
        mock_settings.FIREBASE_CREDENTIALS_PATH = "/path/to/creds.json"
        mock_get_app.return_value = MagicMock()  # non-None firebase app

        mock_messaging = MagicMock()
        mock_messaging.Notification = MagicMock
        mock_messaging.Message = MagicMock
        mock_messaging.AndroidConfig = MagicMock
        mock_messaging.AndroidNotification = MagicMock
        mock_messaging.APNSConfig = MagicMock
        mock_messaging.APNSPayload = MagicMock
        mock_messaging.Aps = MagicMock

        with patch.dict("sys.modules", {"firebase_admin": MagicMock(), "firebase_admin.messaging": mock_messaging}):
            with patch("app.services.notifications.asyncio.to_thread", new_callable=AsyncMock) as mock_thread:
                mock_thread.return_value = "projects/test/messages/abc123"

                from app.services.notifications import send_push_notification

                result = await send_push_notification(
                    "valid-fcm-token", "Test Title", "Test Body", {"key": "value"}
                )

        assert result is True
        mock_thread.assert_awaited_once()

    @pytest.mark.anyio
    @patch("app.services.notifications._get_firebase_app")
    @patch("app.services.notifications.settings")
    async def test_push_invalid_token(self, mock_settings, mock_get_app):
        """UNREGISTERED error returns None (signals stale token)."""
        mock_settings.is_development = False
        mock_settings.FIREBASE_CREDENTIALS_PATH = "/path/to/creds.json"
        mock_get_app.return_value = MagicMock()

        mock_messaging = MagicMock()
        mock_messaging.Notification = MagicMock
        mock_messaging.Message = MagicMock
        mock_messaging.AndroidConfig = MagicMock
        mock_messaging.AndroidNotification = MagicMock
        mock_messaging.APNSConfig = MagicMock
        mock_messaging.APNSPayload = MagicMock
        mock_messaging.Aps = MagicMock

        with patch.dict("sys.modules", {"firebase_admin": MagicMock(), "firebase_admin.messaging": mock_messaging}):
            with patch("app.services.notifications.asyncio.to_thread", new_callable=AsyncMock) as mock_thread:
                mock_thread.side_effect = Exception(
                    "Requested entity was not found. UNREGISTERED"
                )

                from app.services.notifications import send_push_notification

                result = await send_push_notification("expired-token", "Title", "Body")

        assert result is None

    @pytest.mark.anyio
    @patch("app.services.notifications._get_firebase_app")
    @patch("app.services.notifications.settings")
    async def test_push_transient_failure(self, mock_settings, mock_get_app):
        """Generic exception returns False."""
        mock_settings.is_development = False
        mock_settings.FIREBASE_CREDENTIALS_PATH = "/path/to/creds.json"
        mock_get_app.return_value = MagicMock()

        with patch("app.services.notifications.asyncio.to_thread", new_callable=AsyncMock) as mock_thread:
            mock_thread.side_effect = Exception("Network timeout")

            from app.services.notifications import send_push_notification

            result = await send_push_notification("valid-token", "Title", "Body")

        assert result is False


# ─────────────────────────────────────────────
# Push to User — send_push_to_user
# ─────────────────────────────────────────────


class TestSendPushToUser:
    """Tests for send_push_to_user()."""

    @pytest.mark.anyio
    async def test_push_to_user_no_token(self):
        """When DB returns no FCM token, returns False."""
        mock_db = AsyncMock()
        mock_db.execute = AsyncMock(return_value=mock_db_result(scalar_value=None))

        from app.services.notifications import send_push_to_user

        result = await send_push_to_user(mock_db, "user-123", "Title", "Body")
        assert result is False

    @pytest.mark.anyio
    @patch("app.services.notifications.send_push_notification", new_callable=AsyncMock)
    async def test_push_to_user_success(self, mock_send_push):
        """When user has a token and push succeeds, returns True."""
        mock_send_push.return_value = True

        mock_db = AsyncMock()
        mock_db.execute = AsyncMock(
            return_value=mock_db_result(scalar_value="valid-fcm-token")
        )

        from app.services.notifications import send_push_to_user

        result = await send_push_to_user(mock_db, "user-123", "Title", "Body")
        assert result is True
        mock_send_push.assert_awaited_once_with("valid-fcm-token", "Title", "Body", None)

    @pytest.mark.anyio
    @patch("app.services.notifications.send_push_notification", new_callable=AsyncMock)
    async def test_push_to_user_clears_stale_token(self, mock_send_push):
        """When send_push returns None (stale token), DB update is called to clear it."""
        mock_send_push.return_value = None  # signals invalid token

        mock_db = AsyncMock()
        # First call: returns fcm_token; second call: the update statement
        mock_db.execute = AsyncMock(
            side_effect=[
                mock_db_result(scalar_value="stale-fcm-token"),
                MagicMock(),  # result of the UPDATE query
            ]
        )
        mock_db.commit = AsyncMock()

        from app.services.notifications import send_push_to_user

        result = await send_push_to_user(mock_db, "user-123", "Title", "Body")

        # Returns False because result is None (not True)
        assert result is False
        # Verify the DB was called to clear the stale token (execute called twice)
        assert mock_db.execute.await_count == 2
        mock_db.commit.assert_awaited_once()
