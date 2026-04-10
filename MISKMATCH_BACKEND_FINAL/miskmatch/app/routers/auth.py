"""
MiskMatch — Auth Router
Registration, login, OTP verification, token refresh.
"""

import random
import string
from datetime import datetime, timezone
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status, BackgroundTasks
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.config import settings
from app.core.database import get_db
from app.core.redis import is_token_blacklisted, blacklist_token, blacklist_all_user_tokens
from app.core.security import (
    hash_password, verify_password, is_password_strong,
    create_access_token, create_refresh_token,
    decode_token, create_otp_token,
)
from app.models.models import User, UserRole, UserStatus, Gender
from app.schemas.auth import (
    RegisterRequest, LoginRequest, TokenResponse,
    OTPVerifyRequest, RefreshTokenRequest, DeviceTokenRequest,
)
from app.services.notifications import send_otp_sms

router = APIRouter(prefix="/auth", tags=["Authentication"])
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")


# ─────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────

def generate_otp(length: int = 6) -> str:
    """Generate a numeric OTP."""
    return "".join(random.choices(string.digits, k=length))


async def get_current_user(
    token: Annotated[str, Depends(oauth2_scheme)],
    db: AsyncSession = Depends(get_db),
) -> User:
    """
    Dependency: extract and validate current user from JWT.
    Use in protected routes: current_user: User = Depends(get_current_user)
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = decode_token(token)
        user_id: str = payload.get("sub")
        token_type: str = payload.get("type")
        jti: str = payload.get("jti", "")
        if user_id is None or token_type != "access":
            raise credentials_exception
        # Check if this specific token has been revoked
        # Tokens without JTI cannot be individually revoked — reject them
        if not jti:
            raise credentials_exception
        if await is_token_blacklisted(jti):
            raise credentials_exception
    except HTTPException:
        raise
    except Exception:
        raise credentials_exception

    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()

    if user is None:
        raise credentials_exception
    if user.status == UserStatus.BANNED:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account has been banned",
        )
    if user.status == UserStatus.SUSPENDED:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is temporarily suspended",
        )
    if user.status == UserStatus.DEACTIVATED:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account has been deleted",
        )
    return user


async def get_current_active_user(
    current_user: Annotated[User, Depends(get_current_user)],
) -> User:
    """Only allow fully active users."""
    if current_user.status != UserStatus.ACTIVE:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account not yet fully verified",
        )
    return current_user


# ─────────────────────────────────────────────
# REGISTER
# ─────────────────────────────────────────────

@router.post(
    "/register",
    status_code=status.HTTP_201_CREATED,
    summary="Register a new user",
)
async def register(
    body: RegisterRequest,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
):
    """
    Register a new MiskMatch user.

    1. Validate phone not already registered
    2. Validate password strength
    3. Hash password
    4. Create user record
    5. Send OTP via SMS
    """

    # Check phone uniqueness
    result = await db.execute(select(User).where(User.phone == body.phone))
    if result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Phone number already registered",
        )

    # Validate password
    if not is_password_strong(body.password):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Password must be 8+ chars with uppercase, lowercase, and digit",
        )

    # Create user
    user = User(
        phone=body.phone,
        email=body.email,
        password_hash=hash_password(body.password),
        gender=body.gender,
        role=UserRole.USER,
        status=UserStatus.PENDING,
        niyyah=body.niyyah,
    )
    db.add(user)
    await db.flush()  # get the ID before commit

    # Generate and send OTP
    otp = generate_otp()
    otp_token = create_otp_token(body.phone, otp)

    # Send OTP in background (don't block response)
    background_tasks.add_task(send_otp_sms, body.phone, otp)

    await db.commit()

    return {
        "message": "Registration successful. OTP sent to your phone.",
        "user_id": str(user.id),
        "otp_token": otp_token,  # client uses this to verify OTP
        "phone": body.phone,
    }


# ─────────────────────────────────────────────
# VERIFY OTP
# ─────────────────────────────────────────────

@router.post(
    "/verify-otp",
    summary="Verify phone OTP",
)
async def verify_otp(
    body: OTPVerifyRequest,
    db: AsyncSession = Depends(get_db),
):
    """
    Verify the OTP sent to user's phone.
    On success: mark phone as verified and activate account.
    """
    from jose import JWTError

    try:
        payload = decode_token(body.otp_token)
        if payload.get("type") != "otp":
            raise HTTPException(status_code=400, detail="Invalid token type")
        if payload.get("otp") != body.otp:
            raise HTTPException(status_code=400, detail="Incorrect OTP")
        phone = payload.get("sub")
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="OTP expired or invalid. Request a new one.",
        )

    result = await db.execute(select(User).where(User.phone == phone))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    user.phone_verified = True
    user.status = UserStatus.ACTIVE
    await db.commit()

    # Issue tokens
    access_token = create_access_token(
        subject=user.id,
        extra_claims={"role": user.role, "gender": user.gender},
    )
    refresh_token = create_refresh_token(subject=user.id)

    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        token_type="bearer",
        user_id=str(user.id),
        role=user.role,
        gender=user.gender,
        onboarding_completed=user.onboarding_completed,
    )


# ─────────────────────────────────────────────
# LOGIN
# ─────────────────────────────────────────────

@router.post(
    "/login",
    summary="Login with phone + password",
    response_model=TokenResponse,
)
async def login(
    body: LoginRequest,
    db: AsyncSession = Depends(get_db),
):
    """
    Authenticate user with phone and password.
    Returns access + refresh JWT tokens.
    """
    result = await db.execute(select(User).where(User.phone == body.phone))
    user = result.scalar_one_or_none()

    if not user or not verify_password(body.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect phone number or password",
        )

    if user.status == UserStatus.BANNED:
        raise HTTPException(status_code=403, detail="Account banned")

    if user.status == UserStatus.PENDING:
        raise HTTPException(
            status_code=403,
            detail="Phone not verified. Check your SMS for the OTP.",
        )

    # Update last seen
    user.last_seen_at = datetime.now(timezone.utc)
    await db.commit()

    access_token = create_access_token(
        subject=user.id,
        extra_claims={"role": user.role, "gender": user.gender},
    )
    refresh_token = create_refresh_token(subject=user.id)

    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        token_type="bearer",
        user_id=str(user.id),
        role=user.role,
        gender=user.gender,
        onboarding_completed=user.onboarding_completed,
    )


# ─────────────────────────────────────────────
# REFRESH TOKEN
# ─────────────────────────────────────────────

@router.post(
    "/refresh",
    summary="Refresh access token",
    response_model=TokenResponse,
)
async def refresh_token(
    body: RefreshTokenRequest,
    db: AsyncSession = Depends(get_db),
):
    """
    Use a valid refresh token to get a new access token.
    Called automatically by Flutter HTTP client when 401 received.
    """
    from jose import JWTError

    try:
        payload = decode_token(body.refresh_token)
        if payload.get("type") != "refresh":
            raise HTTPException(status_code=400, detail="Invalid token type")
        user_id = payload.get("sub")
        old_jti = payload.get("jti", "")
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token expired. Please login again.",
        )

    # Prevent refresh token replay — reject if already used
    if old_jti and await is_token_blacklisted(old_jti):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token has already been used. Please login again.",
        )

    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()

    if not user or user.status in [UserStatus.BANNED, UserStatus.DEACTIVATED]:
        raise HTTPException(status_code=401, detail="User not found or inactive")

    # Blacklist the old refresh token so it can't be replayed
    if old_jti:
        ttl = settings.REFRESH_TOKEN_EXPIRE_DAYS * 86400
        await blacklist_token(old_jti, ttl)

    new_access = create_access_token(
        subject=user.id,
        extra_claims={"role": user.role, "gender": user.gender},
    )
    new_refresh = create_refresh_token(subject=user.id)

    return TokenResponse(
        access_token=new_access,
        refresh_token=new_refresh,
        token_type="bearer",
        user_id=str(user.id),
        role=user.role,
        gender=user.gender,
        onboarding_completed=user.onboarding_completed,
    )


# ─────────────────────────────────────────────
# RESEND OTP
# ─────────────────────────────────────────────

@router.post("/resend-otp", summary="Resend OTP to phone")
async def resend_otp(
    phone: str,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
):
    """Resend OTP. Rate-limited to once per 60 seconds in middleware."""
    result = await db.execute(select(User).where(User.phone == phone))
    user = result.scalar_one_or_none()

    if not user:
        # Don't reveal if phone exists or not — security
        return {"message": "If this phone is registered, an OTP will be sent."}

    otp = generate_otp()
    otp_token = create_otp_token(phone, otp)
    background_tasks.add_task(send_otp_sms, phone, otp)

    return {
        "message": "OTP sent",
        "otp_token": otp_token,
    }


# ─────────────────────────────────────────────
# LOGOUT (invalidate token — client-side)
# ─────────────────────────────────────────────

@router.post("/logout", summary="Logout current user")
async def logout(
    token: Annotated[str, Depends(oauth2_scheme)],
    current_user: Annotated[User, Depends(get_current_user)],
    db: AsyncSession = Depends(get_db),
):
    """
    Logout — revoke the current access token and clear FCM token.
    Client also deletes tokens from secure storage.
    """
    # Blacklist the current access token
    try:
        payload = decode_token(token)
        jti = payload.get("jti")
        if jti:
            ttl = settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60
            await blacklist_token(jti, ttl)
    except Exception:
        pass  # token already validated by get_current_user

    current_user.fcm_token = None
    await db.commit()
    return {"message": "Logged out successfully"}


# ─────────────────────────────────────────────
# DEVICE TOKEN (FCM)
# ─────────────────────────────────────────────

@router.post("/device-token", summary="Register FCM device token")
async def register_device_token(
    body: DeviceTokenRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    db: AsyncSession = Depends(get_db),
):
    """
    Register or update the FCM device token for push notifications.
    Called by the Flutter app on every launch and on token refresh.
    """
    current_user.fcm_token = body.token
    await db.commit()
    return {"message": "Device token registered"}


# ─────────────────────────────────────────────
# DELETE ACCOUNT
# ─────────────────────────────────────────────

@router.delete("/account", summary="Delete user account")
async def delete_account(
    current_user: Annotated[User, Depends(get_current_user)],
    db: AsyncSession = Depends(get_db),
):
    """
    Soft-delete the user account.
    - Sets status to DEACTIVATED
    - Sets deleted_at timestamp
    - Clears FCM token
    - Closes all active matches
    Required by App Store / Play Store policies.
    """
    from app.models.models import Match, MatchStatus

    current_user.status = UserStatus.DEACTIVATED
    current_user.deleted_at = datetime.now(timezone.utc)
    current_user.fcm_token = None

    # Close all active/pending matches
    result = await db.execute(
        select(Match).where(
            (
                (Match.sender_id == current_user.id) |
                (Match.receiver_id == current_user.id)
            ) &
            Match.status.in_([
                MatchStatus.PENDING, MatchStatus.MUTUAL,
                MatchStatus.APPROVED, MatchStatus.ACTIVE,
            ])
        )
    )
    active_matches = result.scalars().all()
    for match in active_matches:
        match.status = MatchStatus.CLOSED
        match.closed_reason = "account_deleted"

    await db.commit()

    # Invalidate all outstanding tokens for this user
    await blacklist_all_user_tokens(str(current_user.id))

    return {
        "message": "Your account has been deactivated. All matches have been closed.",
        "matches_closed": len(active_matches),
    }
