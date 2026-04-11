"""MiskMatch — Notification Services"""

import asyncio
import logging
from typing import Optional
from app.core.config import settings

logger = logging.getLogger(__name__)

# ─────────────────────────────────────────────
# Firebase Admin SDK — initialised once on import
# ─────────────────────────────────────────────
_firebase_app = None

def _get_firebase_app():
    """Lazy-initialise the Firebase Admin SDK."""
    global _firebase_app
    if _firebase_app is not None:
        return _firebase_app

    if not settings.FIREBASE_CREDENTIALS_PATH:
        logger.warning("FIREBASE_CREDENTIALS_PATH not set — push notifications disabled")
        return None

    try:
        import firebase_admin
        from firebase_admin import credentials

        cred = credentials.Certificate(settings.FIREBASE_CREDENTIALS_PATH)
        _firebase_app = firebase_admin.initialize_app(cred)
        logger.info("Firebase Admin SDK initialised")
        return _firebase_app
    except (ImportError, ValueError, OSError) as e:
        logger.error(f"Firebase Admin SDK init failed ({type(e).__name__}): {e}")
        return None


# ─────────────────────────────────────────────
# SMS — Twilio
# ─────────────────────────────────────────────

async def send_otp_sms(phone: str, otp: str) -> None:
    """Send OTP via Twilio SMS."""
    if settings.is_development:
        logger.info(f"[DEV] OTP sent to {phone[:6]}***")
        return

    if not settings.TWILIO_ACCOUNT_SID or not settings.TWILIO_AUTH_TOKEN:
        logger.error("Twilio credentials not configured — cannot send OTP SMS")
        return

    try:
        from twilio.rest import Client
        client = Client(settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN)
        await asyncio.to_thread(
            client.messages.create,
            body=f"Your MiskMatch verification code is: {otp}\n\nختامه مسك 🌹",
            from_=settings.TWILIO_PHONE,
            to=phone,
        )
        logger.info(f"OTP SMS sent to {phone[:6]}***")
    except ImportError:
        logger.error(f"SMS failed for {phone[:6]}***: twilio package not installed")
    except Exception as e:  # TwilioRestException and network errors
        logger.error(f"SMS failed for {phone[:6]}*** ({type(e).__name__}): {e}")


async def send_sms(phone: str, body: str) -> bool:
    """Send a generic SMS via Twilio. Returns True on success."""
    if settings.is_development:
        logger.info(f"[DEV] SMS to {phone}: {body[:80]}...")
        return True

    if not settings.TWILIO_ACCOUNT_SID or not settings.TWILIO_AUTH_TOKEN:
        logger.error("Twilio credentials not configured")
        return False

    try:
        from twilio.rest import Client
        client = Client(settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN)
        await asyncio.to_thread(
            client.messages.create,
            body=body,
            from_=settings.TWILIO_PHONE,
            to=phone,
        )
        logger.info(f"SMS sent to {phone[:6]}***")
        return True
    except ImportError:
        logger.error(f"SMS failed for {phone[:6]}***: twilio package not installed")
        return False
    except Exception as e:  # TwilioRestException and network errors
        logger.error(f"SMS failed for {phone[:6]}*** ({type(e).__name__}): {e}")
        return False


# ─────────────────────────────────────────────
# Push Notifications — Firebase Cloud Messaging
# ─────────────────────────────────────────────

async def send_push_notification(
    fcm_token: str,
    title: str,
    body: str,
    data: Optional[dict] = None,
) -> bool:
    """
    Send a push notification via Firebase Cloud Messaging.
    Returns True on success, False on transient failure, None if token is invalid.
    """
    if not fcm_token:
        return False

    if settings.is_development and not settings.FIREBASE_CREDENTIALS_PATH:
        logger.info(f"[DEV] Push → {title}: {body}")
        return True

    app = _get_firebase_app()
    if app is None:
        logger.warning(f"Firebase not available — skipping push: {title}")
        return False

    try:
        from firebase_admin import messaging

        # Build the message
        notification = messaging.Notification(title=title, body=body)

        # Convert all data values to strings (FCM requirement)
        str_data = {k: str(v) for k, v in (data or {}).items()} if data else None

        message = messaging.Message(
            notification=notification,
            data=str_data,
            token=fcm_token,
            android=messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    channel_id="miskmatch_default",
                    icon="ic_notification",
                    sound="default",
                ),
            ),
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(
                        sound="default",
                        badge=1,
                    ),
                ),
            ),
        )

        response = await asyncio.to_thread(messaging.send, message)
        logger.info(f"Push sent: {title} → {response}")
        return True

    except Exception as e:  # firebase_admin.messaging errors + network
        error_msg = str(e)
        if "UNREGISTERED" in error_msg or "INVALID_ARGUMENT" in error_msg:
            logger.warning(f"FCM token invalid/expired for push: {title}")
            return None  # signals caller to clear the stale token
        else:
            logger.error(f"Push notification failed: {e}")
            return False


async def send_push_to_user(
    db,
    user_id,
    title: str,
    body: str,
    data: Optional[dict] = None,
) -> bool:
    """
    Convenience: look up user's FCM token and send push.
    Returns True if push was sent successfully.
    """
    from sqlalchemy import select
    from app.models.models import User

    result = await db.execute(select(User.fcm_token).where(User.id == user_id))
    fcm_token = result.scalar_one_or_none()

    if not fcm_token:
        logger.debug(f"No FCM token for user {user_id} — skipping push")
        return False

    result = await send_push_notification(fcm_token, title, body, data)

    # None means the token is invalid/expired — clear it
    if result is None:
        from sqlalchemy import update
        await db.execute(
            update(User).where(User.id == user_id).values(fcm_token=None)
        )
        await db.commit()
        logger.info(f"Cleared stale FCM token for user {user_id}")

    return result is True
