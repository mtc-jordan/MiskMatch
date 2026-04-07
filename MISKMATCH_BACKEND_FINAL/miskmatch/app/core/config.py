"""
MiskMatch — Core Settings
All config loaded from environment variables with validation.
"""

from functools import lru_cache
from typing import List, Optional
from pydantic import AnyHttpUrl, EmailStr, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    # ─── App ───────────────────────────────────
    APP_NAME: str = "MiskMatch"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = False
    ENVIRONMENT: str = "development"
    SECRET_KEY: str
    API_V1_PREFIX: str = "/api/v1"

    ALLOWED_HOSTS: List[str] = ["localhost", "127.0.0.1"]
    ALLOWED_ORIGINS: List[str] = [
        "http://localhost:3000",
        "http://localhost:8080",
    ]

    # ─── Database ──────────────────────────────
    DATABASE_URL: str
    DATABASE_URL_SYNC: str
    DB_POOL_SIZE: int = 20
    DB_MAX_OVERFLOW: int = 40

    # ─── Cache ─────────────────────────────────
    REDIS_URL: str = "redis://localhost:6379/0"
    CACHE_TTL: int = 3600

    # ─── Auth ──────────────────────────────────
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30
    ALGORITHM: str = "HS256"

    # ─── Storage ───────────────────────────────
    AWS_ACCESS_KEY_ID: str = ""
    AWS_SECRET_ACCESS_KEY: str = ""
    AWS_REGION: str = "me-south-1"
    S3_BUCKET_PROFILES: str = "miskmatch-profiles"
    S3_BUCKET_MEDIA: str = "miskmatch-media"
    CLOUDFRONT_URL: str = ""

    # ─── Twilio ────────────────────────────────
    TWILIO_ACCOUNT_SID: str = ""
    TWILIO_AUTH_TOKEN: str = ""
    TWILIO_PHONE: str = ""

    # ─── Email ─────────────────────────────────
    SENDGRID_API_KEY: str = ""
    FROM_EMAIL: EmailStr = "noreply@miskmatch.app"
    FROM_NAME: str = "MiskMatch"

    # ─── Biometric ─────────────────────────────
    ONFIDO_API_KEY: str = ""
    ONFIDO_WEBHOOK_SECRET: str = ""

    # ─── Video ─────────────────────────────────
    AGORA_APP_ID: str = ""
    AGORA_APP_CERT: str = ""

    # ─── Payments ──────────────────────────────
    STRIPE_SECRET_KEY: str = ""
    STRIPE_WEBHOOK_SECRET: str = ""
    STRIPE_PRICE_NOOR_MONTHLY: str = ""
    STRIPE_PRICE_MISK_MONTHLY: str = ""

    # ─── AI ────────────────────────────────────
    OPENAI_API_KEY: str = ""
    ANTHROPIC_API_KEY: str = ""

    # ─── Monitoring ────────────────────────────
    SENTRY_DSN: Optional[str] = None

    # ─── Admin ─────────────────────────────────
    ADMIN_EMAIL: EmailStr = "admin@miskmatch.app"
    ADMIN_PASSWORD: str = ""

    @field_validator("SECRET_KEY")
    @classmethod
    def secret_key_must_be_strong(cls, v: str) -> str:
        if len(v) < 32:
            raise ValueError("SECRET_KEY must be at least 32 characters")
        return v

    @property
    def is_production(self) -> bool:
        return self.ENVIRONMENT == "production"

    @property
    def is_development(self) -> bool:
        return self.ENVIRONMENT == "development"


@lru_cache
def get_settings() -> Settings:
    """Cached settings — only loaded once."""
    return Settings()


settings = get_settings()
