"""
MiskMatch — Webhook Endpoint Tests
Tests for Stripe and Onfido webhook signature verification and event handling.
"""

import hashlib
import hmac
import json
import pytest
from unittest.mock import AsyncMock, MagicMock, patch

from tests.conftest import mock_db_result

# Ensure 'stripe' module is available even if not installed
_stripe_mock = MagicMock()
_stripe_mock.SignatureVerificationError = type("SignatureVerificationError", (Exception,), {})
_stripe_mock.Webhook = MagicMock()


@pytest.fixture(autouse=True)
def _mock_stripe_module():
    """Make 'import stripe' succeed even without the package installed."""
    import sys
    with patch.dict(sys.modules, {"stripe": _stripe_mock}):
        yield


# ─────────────────────────────────────────────
# STRIPE WEBHOOKS
# ─────────────────────────────────────────────


class TestStripeWebhook:
    """Tests for POST /api/v1/webhooks/stripe."""

    URL = "/api/v1/webhooks/stripe"

    @pytest.mark.anyio
    async def test_stripe_missing_signature(self, client):
        """Request without Stripe-Signature header returns 400."""
        resp = await client.post(self.URL, content=b'{"type":"test"}')
        assert resp.status_code == 400
        assert "Missing Stripe-Signature" in resp.json()["detail"]

    @pytest.mark.anyio
    @patch("app.routers.webhooks.settings")
    async def test_stripe_invalid_signature(self, mock_settings, client):
        """Invalid signature triggers SignatureVerificationError and returns 400."""
        mock_settings.STRIPE_WEBHOOK_SECRET = "whsec_test_secret"
        mock_settings.API_V1_PREFIX = "/api/v1"

        import stripe

        with patch("stripe.Webhook.construct_event") as mock_construct:
            mock_construct.side_effect = stripe.SignatureVerificationError(
                "bad sig", "sig_header"
            )
            resp = await client.post(
                self.URL,
                content=b'{"type":"test"}',
                headers={"stripe-signature": "bad_sig"},
            )
        assert resp.status_code == 400
        assert "Invalid signature" in resp.json()["detail"]

    @pytest.mark.anyio
    @patch("app.routers.webhooks.settings")
    async def test_stripe_invoice_paid(self, mock_settings, client):
        """invoice.paid event activates the user's subscription."""
        mock_settings.STRIPE_WEBHOOK_SECRET = "whsec_test_secret"
        mock_settings.STRIPE_PRICE_NOOR_MONTHLY = "price_noor"
        mock_settings.STRIPE_PRICE_MISK_MONTHLY = "price_misk"

        event_payload = {
            "type": "invoice.paid",
            "data": {
                "object": {
                    "customer": "cus_123",
                    "subscription": "sub_456",
                    "amount_paid": 999,
                    "currency": "usd",
                    "payment_intent": "pi_789",
                    "lines": {
                        "data": [
                            {
                                "price": {"id": "price_noor"},
                                "period": {"end": 1700000000},
                            }
                        ]
                    },
                }
            },
        }

        mock_user = MagicMock()
        mock_user.id = "user-abc"
        mock_user.subscription_expires_at = None

        mock_db = AsyncMock()
        mock_db.execute = AsyncMock(return_value=mock_db_result(scalar_value=mock_user))
        mock_db.commit = AsyncMock()
        mock_db.add = MagicMock()

        from app.main import app
        from app.core.database import get_db

        async def override_get_db():
            yield mock_db

        with patch("stripe.Webhook.construct_event", return_value=event_payload):
            app.dependency_overrides[get_db] = override_get_db
            try:
                resp = await client.post(
                    self.URL,
                    content=json.dumps(event_payload).encode(),
                    headers={"stripe-signature": "valid_sig"},
                )
            finally:
                app.dependency_overrides.pop(get_db, None)

        assert resp.status_code == 200
        assert resp.json()["received"] is True
        mock_db.commit.assert_awaited()

    @pytest.mark.anyio
    @patch("app.routers.webhooks.settings")
    async def test_stripe_subscription_deleted(self, mock_settings, client):
        """customer.subscription.deleted resets the user to BARAKAH tier."""
        mock_settings.STRIPE_WEBHOOK_SECRET = "whsec_test_secret"
        mock_settings.STRIPE_PRICE_NOOR_MONTHLY = "price_noor"
        mock_settings.STRIPE_PRICE_MISK_MONTHLY = "price_misk"

        event_payload = {
            "type": "customer.subscription.deleted",
            "data": {
                "object": {
                    "customer": "cus_123",
                }
            },
        }

        mock_user = MagicMock()
        mock_user.id = "user-abc"
        mock_user.subscription_tier = None
        mock_user.subscription_expires_at = None

        mock_db = AsyncMock()
        mock_db.execute = AsyncMock(return_value=mock_db_result(scalar_value=mock_user))
        mock_db.commit = AsyncMock()

        with patch("stripe.Webhook.construct_event", return_value=event_payload):
            from app.main import app
            from app.core.database import get_db

            app.dependency_overrides[get_db] = lambda: mock_db
            try:
                resp = await client.post(
                    self.URL,
                    content=json.dumps(event_payload).encode(),
                    headers={"stripe-signature": "valid_sig"},
                )
            finally:
                app.dependency_overrides.pop(get_db, None)

        assert resp.status_code == 200
        assert resp.json()["received"] is True
        mock_db.commit.assert_awaited()
        # Verify user was downgraded
        from app.models.models import SubscriptionTier

        assert mock_user.subscription_tier == SubscriptionTier.BARAKAH
        assert mock_user.subscription_expires_at is None


# ─────────────────────────────────────────────
# ONFIDO WEBHOOKS
# ─────────────────────────────────────────────


class TestOnfidoWebhook:
    """Tests for POST /api/v1/webhooks/onfido."""

    URL = "/api/v1/webhooks/onfido"

    @pytest.mark.anyio
    async def test_onfido_missing_signature(self, client):
        """Request without X-SHA2-Signature header returns 400."""
        resp = await client.post(self.URL, content=b'{"test":true}')
        assert resp.status_code == 400
        assert "Missing X-SHA2-Signature" in resp.json()["detail"]

    @pytest.mark.anyio
    @patch("app.routers.webhooks.settings")
    async def test_onfido_invalid_signature(self, mock_settings, client):
        """Wrong HMAC signature returns 400."""
        mock_settings.ONFIDO_WEBHOOK_SECRET = "onfido_secret_123"

        resp = await client.post(
            self.URL,
            content=b'{"payload":{}}',
            headers={"X-SHA2-Signature": "definitely_wrong_signature"},
        )
        assert resp.status_code == 400
        assert "Invalid signature" in resp.json()["detail"]

    @pytest.mark.anyio
    @patch("app.routers.webhooks.settings")
    async def test_onfido_check_completed(self, mock_settings, client):
        """check.completed with result 'clear' sets user id_verified to VERIFIED."""
        secret = "onfido_secret_123"
        mock_settings.ONFIDO_WEBHOOK_SECRET = secret

        payload_dict = {
            "payload": {
                "action": "check.completed",
                "object": {
                    "applicant_id": "applicant_abc",
                    "result": "clear",
                },
            }
        }
        payload_bytes = json.dumps(payload_dict).encode()

        # Compute valid HMAC
        valid_sig = hmac.new(
            secret.encode("utf-8"), payload_bytes, hashlib.sha256
        ).hexdigest()

        mock_user = MagicMock()
        mock_user.id = "user-xyz"
        mock_user.id_verified = None

        mock_profile = MagicMock()
        mock_profile.trust_score = 50

        # DB returns user on first call, profile on second call
        mock_db = AsyncMock()
        mock_db.execute = AsyncMock(
            side_effect=[
                mock_db_result(scalar_value=mock_user),
                mock_db_result(scalar_value=mock_profile),
            ]
        )
        mock_db.commit = AsyncMock()

        from app.main import app
        from app.core.database import get_db

        app.dependency_overrides[get_db] = lambda: mock_db
        try:
            resp = await client.post(
                self.URL,
                content=payload_bytes,
                headers={"X-SHA2-Signature": valid_sig},
            )
        finally:
            app.dependency_overrides.pop(get_db, None)

        assert resp.status_code == 200
        assert resp.json()["received"] is True
        mock_db.commit.assert_awaited()

        from app.models.models import VerificationStatus

        assert mock_user.id_verified == VerificationStatus.VERIFIED
        assert mock_profile.trust_score == 70  # 50 + 20
