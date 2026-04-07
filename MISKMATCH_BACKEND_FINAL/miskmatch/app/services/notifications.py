"""MiskMatch — Notification Services"""

from app.core.config import settings


async def send_otp_sms(phone: str, otp: str) -> None:
    """Send OTP via Twilio SMS."""
    if settings.is_development:
        print(f"[DEV] OTP for {phone}: {otp}")
        return
    try:
        from twilio.rest import Client
        client = Client(settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN)
        client.messages.create(
            body=f"Your MiskMatch verification code is: {otp}\n\nختامه مسك 🌹",
            from_=settings.TWILIO_PHONE,
            to=phone,
        )
    except Exception as e:
        print(f"SMS failed: {e}")


async def send_push_notification(fcm_token: str, title: str, body: str, data: dict = None) -> None:
    """Send Firebase push notification."""
    # Implement with firebase-admin SDK
    pass
