"""
MiskMatch — Webhook Endpoints
Handles incoming webhooks from Stripe and Onfido with signature verification.

Endpoints:
    POST /webhooks/stripe  → Stripe subscription/payment events
    POST /webhooks/onfido  → Onfido biometric verification events
"""

import logging
from datetime import datetime, timezone

from fastapi import APIRouter, Request, HTTPException, status, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_db
from app.models.models import (
    User, Subscription, SubscriptionTier,
    VerificationStatus,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/webhooks", tags=["Webhooks"])


# ─────────────────────────────────────────────
# STRIPE WEBHOOKS
# ─────────────────────────────────────────────

@router.post("/stripe", summary="Handle Stripe webhook events")
async def stripe_webhook(
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    """
    Handle Stripe webhook events for subscription management.

    Verifies the webhook signature using STRIPE_WEBHOOK_SECRET,
    then processes the following events:
      - invoice.paid               → activate/renew subscription
      - customer.subscription.updated → handle plan changes
      - customer.subscription.deleted → handle cancellation
      - invoice.payment_failed     → log failed payment
    """
    import stripe

    payload = await request.body()
    sig_header = request.headers.get("stripe-signature")

    if not sig_header:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Missing Stripe-Signature header",
        )

    if not settings.STRIPE_WEBHOOK_SECRET:
        logger.error("STRIPE_WEBHOOK_SECRET not configured — rejecting webhook")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Webhook secret not configured",
        )

    # Verify signature
    try:
        event = stripe.Webhook.construct_event(
            payload, sig_header, settings.STRIPE_WEBHOOK_SECRET
        )
    except stripe.SignatureVerificationError:
        logger.warning("Stripe webhook signature verification failed")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid signature",
        )
    except Exception as e:
        logger.error(f"Stripe webhook parse error: {e}")
        raise HTTPException(status_code=400, detail="Invalid payload")

    event_type = event["type"]
    data = event["data"]["object"]
    logger.info(f"Stripe webhook received: {event_type}")

    # ── invoice.paid — activate or renew subscription ──
    if event_type == "invoice.paid":
        customer_id = data.get("customer")
        subscription_id = data.get("subscription")
        amount_paid = data.get("amount_paid", 0)  # in cents

        if not customer_id:
            return {"received": True}

        # Find user by Stripe customer ID
        result = await db.execute(
            select(User).where(User.stripe_customer_id == customer_id)
        )
        user = result.scalar_one_or_none()
        if not user:
            logger.warning(f"Stripe webhook: no user for customer {customer_id}")
            return {"received": True}

        # Determine tier from the subscription items
        tier = _resolve_tier_from_stripe(data)

        # Update user subscription
        user.subscription_tier = tier
        if data.get("lines", {}).get("data"):
            period_end = data["lines"]["data"][0].get("period", {}).get("end")
            if period_end:
                user.subscription_expires_at = datetime.fromtimestamp(
                    period_end, tz=timezone.utc
                )

        # Record in subscriptions table
        sub = Subscription(
            user_id=user.id,
            tier=tier,
            stripe_subscription_id=subscription_id,
            stripe_payment_intent_id=data.get("payment_intent"),
            amount_cents=amount_paid,
            currency=data.get("currency", "usd").upper(),
            status="active",
            starts_at=datetime.now(timezone.utc),
            ends_at=user.subscription_expires_at,
        )
        db.add(sub)
        await db.commit()

        logger.info(
            f"Subscription activated: user={user.id} tier={tier} "
            f"amount={amount_paid}c"
        )

    # ── customer.subscription.updated — plan change ──
    elif event_type == "customer.subscription.updated":
        customer_id = data.get("customer")
        if customer_id:
            result = await db.execute(
                select(User).where(User.stripe_customer_id == customer_id)
            )
            user = result.scalar_one_or_none()
            if user:
                tier = _resolve_tier_from_stripe(data)
                user.subscription_tier = tier

                current_period_end = data.get("current_period_end")
                if current_period_end:
                    user.subscription_expires_at = datetime.fromtimestamp(
                        current_period_end, tz=timezone.utc
                    )
                await db.commit()
                logger.info(f"Subscription updated: user={user.id} tier={tier}")

    # ── customer.subscription.deleted — cancellation ──
    elif event_type == "customer.subscription.deleted":
        customer_id = data.get("customer")
        if customer_id:
            result = await db.execute(
                select(User).where(User.stripe_customer_id == customer_id)
            )
            user = result.scalar_one_or_none()
            if user:
                user.subscription_tier = SubscriptionTier.BARAKAH
                user.subscription_expires_at = None
                await db.commit()
                logger.info(f"Subscription cancelled: user={user.id}")

    # ── invoice.payment_failed — log for monitoring ──
    elif event_type == "invoice.payment_failed":
        customer_id = data.get("customer")
        logger.warning(
            f"Stripe payment failed: customer={customer_id} "
            f"amount={data.get('amount_due')}c"
        )

    return {"received": True}


def _resolve_tier_from_stripe(data: dict) -> SubscriptionTier:
    """Determine MiskMatch tier from Stripe price IDs."""
    # Check subscription items or invoice line items
    items = []
    if "items" in data and "data" in data["items"]:
        items = data["items"]["data"]
    elif "lines" in data and "data" in data["lines"]:
        items = data["lines"]["data"]

    for item in items:
        price_id = item.get("price", {}).get("id", "")
        if price_id == settings.STRIPE_PRICE_MISK_MONTHLY:
            return SubscriptionTier.MISK
        if price_id == settings.STRIPE_PRICE_NOOR_MONTHLY:
            return SubscriptionTier.NOOR

    return SubscriptionTier.NOOR  # default paid tier


# ─────────────────────────────────────────────
# ONFIDO WEBHOOKS
# ─────────────────────────────────────────────

@router.post("/onfido", summary="Handle Onfido verification webhook")
async def onfido_webhook(
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    """
    Handle Onfido biometric verification webhooks.

    Verifies the webhook signature using ONFIDO_WEBHOOK_SECRET,
    then processes:
      - check.completed → update user's id_verified status
    """
    import hmac
    import hashlib

    payload = await request.body()
    sig_header = request.headers.get("X-SHA2-Signature")

    if not sig_header:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Missing X-SHA2-Signature header",
        )

    if not settings.ONFIDO_WEBHOOK_SECRET:
        logger.error("ONFIDO_WEBHOOK_SECRET not configured — rejecting webhook")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Webhook secret not configured",
        )

    # Verify HMAC-SHA256 signature
    expected_sig = hmac.new(
        settings.ONFIDO_WEBHOOK_SECRET.encode("utf-8"),
        payload,
        hashlib.sha256,
    ).hexdigest()

    if not hmac.compare_digest(expected_sig, sig_header):
        logger.warning("Onfido webhook signature verification failed")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid signature",
        )

    import json
    try:
        body = json.loads(payload)
    except json.JSONDecodeError:
        raise HTTPException(status_code=400, detail="Invalid JSON")

    event_type = body.get("payload", {}).get("action", "")
    resource = body.get("payload", {}).get("object", {})
    logger.info(f"Onfido webhook received: {event_type}")

    if event_type == "check.completed":
        applicant_id = resource.get("applicant_id")
        check_result = resource.get("result", "")  # "clear" or "consider"

        if not applicant_id:
            return {"received": True}

        # Find user by Onfido applicant ID
        result = await db.execute(
            select(User).where(User.onfido_applicant_id == applicant_id)
        )
        user = result.scalar_one_or_none()
        if not user:
            logger.warning(
                f"Onfido webhook: no user for applicant {applicant_id}"
            )
            return {"received": True}

        if check_result == "clear":
            user.id_verified = VerificationStatus.VERIFIED
            logger.info(f"Onfido verified: user={user.id}")

            # Boost trust score for verified users
            from app.models.models import Profile
            profile_result = await db.execute(
                select(Profile).where(Profile.user_id == user.id)
            )
            profile = profile_result.scalar_one_or_none()
            if profile:
                profile.trust_score = min(100, profile.trust_score + 20)
        else:
            user.id_verified = VerificationStatus.FAILED
            logger.warning(
                f"Onfido verification failed: user={user.id} "
                f"result={check_result}"
            )

        await db.commit()

    return {"received": True}
