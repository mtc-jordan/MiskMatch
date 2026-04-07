"""MiskMatch — Auth Schemas (Pydantic v2)"""

from typing import Optional
from pydantic import BaseModel, field_validator
import phonenumbers

from app.models.models import UserRole, Gender


class RegisterRequest(BaseModel):
    phone: str
    email: Optional[str] = None
    password: str
    gender: Gender
    niyyah: Optional[str] = None

    @field_validator("phone")
    @classmethod
    def validate_phone(cls, v: str) -> str:
        try:
            parsed = phonenumbers.parse(v)
            if not phonenumbers.is_valid_number(parsed):
                raise ValueError("Invalid phone number")
            return phonenumbers.format_number(
                parsed, phonenumbers.PhoneNumberFormat.E164
            )
        except Exception:
            raise ValueError("Invalid phone number format. Use +962XXXXXXXXX")


class LoginRequest(BaseModel):
    phone: str
    password: str


class OTPVerifyRequest(BaseModel):
    otp_token: str
    otp: str


class RefreshTokenRequest(BaseModel):
    refresh_token: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str
    user_id: str
    role: UserRole
    onboarding_completed: bool
