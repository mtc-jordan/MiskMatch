"""
MiskMatch — Security Utilities
JWT tokens, password hashing, and auth helpers.
"""

from datetime import datetime, timedelta, timezone
from typing import Optional
from uuid import UUID

from jose import JWTError, jwt
from passlib.context import CryptContext

from app.core.config import settings

# ─────────────────────────────────────────────
# Password hashing — bcrypt
# ─────────────────────────────────────────────
pwd_context = CryptContext(
    schemes=["bcrypt"],
    deprecated="auto",
    bcrypt__rounds=12,  # strong but not too slow
)


def hash_password(password: str) -> str:
    """Hash a plain-text password."""
    return pwd_context.hash(password)


def verify_password(plain: str, hashed: str) -> bool:
    """Verify a password against its hash."""
    return pwd_context.verify(plain, hashed)


def is_password_strong(password: str) -> bool:
    """
    Validate password strength.
    Min 8 chars, at least 1 upper, 1 lower, 1 digit.
    """
    if len(password) < 8:
        return False
    has_upper = any(c.isupper() for c in password)
    has_lower = any(c.islower() for c in password)
    has_digit = any(c.isdigit() for c in password)
    return has_upper and has_lower and has_digit


# ─────────────────────────────────────────────
# JWT Tokens
# ─────────────────────────────────────────────
def create_access_token(
    subject: str | UUID,
    extra_claims: Optional[dict] = None,
) -> str:
    """
    Create a short-lived JWT access token.

    Args:
        subject: User ID (UUID or string)
        extra_claims: Additional claims to include (role, etc.)

    Returns:
        Encoded JWT string
    """
    expire = datetime.now(timezone.utc) + timedelta(
        minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES
    )
    payload = {
        "sub": str(subject),
        "exp": expire,
        "iat": datetime.now(timezone.utc),
        "type": "access",
    }
    if extra_claims:
        payload.update(extra_claims)

    return jwt.encode(payload, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


def create_refresh_token(subject: str | UUID) -> str:
    """
    Create a long-lived JWT refresh token.
    Stored in HTTP-only cookie, not in response body.
    """
    expire = datetime.now(timezone.utc) + timedelta(
        days=settings.REFRESH_TOKEN_EXPIRE_DAYS
    )
    payload = {
        "sub": str(subject),
        "exp": expire,
        "iat": datetime.now(timezone.utc),
        "type": "refresh",
    }
    return jwt.encode(payload, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


def decode_token(token: str) -> dict:
    """
    Decode and validate a JWT token.

    Raises:
        JWTError: If token is invalid or expired
    """
    return jwt.decode(
        token,
        settings.SECRET_KEY,
        algorithms=[settings.ALGORITHM],
    )


def create_verification_token(email: str) -> str:
    """Create a short-lived email verification token (24h)."""
    expire = datetime.now(timezone.utc) + timedelta(hours=24)
    payload = {
        "sub": email,
        "exp": expire,
        "type": "email_verify",
    }
    return jwt.encode(payload, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


def create_otp_token(phone: str, otp: str) -> str:
    """Create a short-lived OTP verification token (10 min)."""
    expire = datetime.now(timezone.utc) + timedelta(minutes=10)
    payload = {
        "sub": phone,
        "otp": otp,
        "exp": expire,
        "type": "otp",
    }
    return jwt.encode(payload, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
