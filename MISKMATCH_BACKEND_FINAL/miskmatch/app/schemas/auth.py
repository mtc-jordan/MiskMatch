"""MiskMatch — Auth Schemas (Pydantic v2)"""

from typing import Optional
from pydantic import BaseModel, field_validator
import phonenumbers

from app.models.models import UserRole, Gender

# MENA country codes supported by MiskMatch
SUPPORTED_REGIONS = {
    "JO",  # Jordan          +962
    "SA",  # Saudi Arabia    +966
    "AE",  # UAE             +971
    "KW",  # Kuwait          +965
    "BH",  # Bahrain         +973
    "QA",  # Qatar           +974
    "OM",  # Oman            +968
    "EG",  # Egypt           +20
    "MA",  # Morocco         +212
    "TR",  # Turkey          +90
    "MY",  # Malaysia        +60
    "GB",  # United Kingdom  +44
    "US",  # United States   +1
    "CA",  # Canada          +1
}

_PHONE_HINT = (
    "Invalid phone number format. "
    "Use international format with country code, e.g. +962XXXXXXXXX, +966XXXXXXXXX"
)


def _validate_phone_e164(v: str) -> str:
    """Parse and validate a phone number, returning E.164 format."""
    try:
        parsed = phonenumbers.parse(v)
        if not phonenumbers.is_valid_number(parsed):
            raise ValueError("Invalid phone number")
        region = phonenumbers.region_code_for_number(parsed)
        if region and region not in SUPPORTED_REGIONS:
            raise ValueError(
                f"Region {region} is not yet supported. "
                "MiskMatch is currently available in MENA, Malaysia, UK, US, and Canada."
            )
        return phonenumbers.format_number(
            parsed, phonenumbers.PhoneNumberFormat.E164
        )
    except phonenumbers.NumberParseException:
        raise ValueError(_PHONE_HINT)


class RegisterRequest(BaseModel):
    phone: str
    email: Optional[str] = None
    password: str
    gender: Gender
    niyyah: Optional[str] = None

    @field_validator("phone")
    @classmethod
    def validate_phone(cls, v: str) -> str:
        return _validate_phone_e164(v)


class LoginRequest(BaseModel):
    phone: str
    password: str

    @field_validator("phone")
    @classmethod
    def validate_phone(cls, v: str) -> str:
        return _validate_phone_e164(v)


class OTPVerifyRequest(BaseModel):
    phone: str
    otp: str

    @field_validator("phone")
    @classmethod
    def validate_phone(cls, v: str) -> str:
        return _validate_phone_e164(v)


class RefreshTokenRequest(BaseModel):
    refresh_token: str


class DeviceTokenRequest(BaseModel):
    token: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str
    user_id: str
    role: UserRole
    gender: str
    onboarding_completed: bool
