"""
MiskMatch — Profile Schemas (Pydantic v2)
Request/response models for all profile endpoints.
"""

from datetime import datetime
from typing import Optional, List
from uuid import UUID

from pydantic import BaseModel, Field, field_validator, model_validator
import phonenumbers

from app.core.sanitize import sanitize_text

from app.models.models import (
    Gender, MadhabChoice, PrayerFrequency, HijabStance,
    VerificationStatus, SubscriptionTier, UserRole,
)


# ─────────────────────────────────────────────
# PROFILE — CREATE / UPDATE
# ─────────────────────────────────────────────

class ProfileCreateRequest(BaseModel):
    """Initial profile creation — called after registration."""

    # Basic info
    first_name: str = Field(..., min_length=2, max_length=50)
    last_name:  str = Field(..., min_length=2, max_length=50)
    display_name: Optional[str] = Field(None, max_length=100)
    date_of_birth: datetime
    city: str = Field(..., min_length=2, max_length=100)
    country: str = Field(..., min_length=2, max_length=2,
                         description="ISO 3166-1 alpha-2 country code")
    nationality: Optional[str] = Field(None, min_length=2, max_length=2)
    languages: Optional[List[str]] = Field(None, max_length=10)

    # Biography
    bio:    Optional[str] = Field(None, max_length=1000)
    bio_ar: Optional[str] = Field(None, max_length=1000)

    # Islamic identity
    madhab:           Optional[MadhabChoice]     = None
    prayer_frequency: Optional[PrayerFrequency]  = None
    hijab_stance:     Optional[HijabStance]      = None
    quran_level:      Optional[str]              = Field(None, max_length=50)
    is_revert:        bool                       = False
    revert_year:      Optional[int]              = Field(None, ge=1900, le=2030)

    # Education & career
    education_level: Optional[str] = Field(None, max_length=100)
    field_of_study:  Optional[str] = Field(None, max_length=100)
    occupation:      Optional[str] = Field(None, max_length=100)
    employer:        Optional[str] = Field(None, max_length=100)
    income_range:    Optional[str] = Field(None, max_length=50)

    # Life goals
    wants_children:        Optional[bool] = None
    num_children_desired:  Optional[str]  = Field(None, max_length=20)
    children_schooling:    Optional[str]  = Field(None, max_length=50)
    hajj_timeline:         Optional[str]  = Field(None, max_length=50)
    wants_hijra:           Optional[bool] = None
    hijra_country:         Optional[str]  = Field(None, max_length=100)
    islamic_finance_stance: Optional[str] = Field(None, max_length=50)
    wife_working_stance:   Optional[str]  = Field(None, max_length=50)

    # Search preferences
    min_age: int = Field(22, ge=18, le=80)
    max_age: int = Field(40, ge=18, le=80)
    preferred_countries: Optional[List[str]] = None
    max_distance_km:     Optional[int]       = Field(None, ge=1, le=20000)

    @field_validator(
        "first_name", "last_name", "display_name", "bio", "bio_ar",
        "city", "occupation", "employer", "education_level", "field_of_study",
        "quran_level", "hijra_country",
        mode="before",
    )
    @classmethod
    def sanitize_strings(cls, v: Optional[str]) -> Optional[str]:
        return sanitize_text(v) if v else v

    @field_validator("country", "nationality")
    @classmethod
    def upper_country(cls, v: Optional[str]) -> Optional[str]:
        return v.upper() if v else v

    @model_validator(mode="after")
    def age_range_valid(self) -> "ProfileCreateRequest":
        if self.min_age > self.max_age:
            raise ValueError("min_age must be less than max_age")
        return self

    @field_validator("date_of_birth")
    @classmethod
    def must_be_adult(cls, v: datetime) -> datetime:
        from datetime import timezone
        age = (datetime.now(timezone.utc) - v.replace(tzinfo=v.tzinfo or timezone.utc)).days / 365.25
        if age < 18:
            raise ValueError("User must be at least 18 years old")
        if age > 80:
            raise ValueError("Invalid date of birth")
        return v


class ProfileUpdateRequest(BaseModel):
    """Partial update — all fields optional."""

    first_name:   Optional[str] = Field(None, min_length=2, max_length=50)
    last_name:    Optional[str] = Field(None, min_length=2, max_length=50)
    display_name: Optional[str] = Field(None, max_length=100)
    city:         Optional[str] = Field(None, min_length=2, max_length=100)
    country:      Optional[str] = Field(None, min_length=2, max_length=2)
    nationality:  Optional[str] = Field(None, min_length=2, max_length=2)
    languages:    Optional[List[str]] = None

    bio:    Optional[str] = Field(None, max_length=1000)
    bio_ar: Optional[str] = Field(None, max_length=1000)

    madhab:           Optional[MadhabChoice]    = None
    prayer_frequency: Optional[PrayerFrequency] = None
    hijab_stance:     Optional[HijabStance]     = None
    quran_level:      Optional[str]             = Field(None, max_length=50)
    is_revert:        Optional[bool]            = None
    revert_year:      Optional[int]             = Field(None, ge=1900, le=2030)

    education_level: Optional[str] = Field(None, max_length=100)
    field_of_study:  Optional[str] = Field(None, max_length=100)
    occupation:      Optional[str] = Field(None, max_length=100)
    employer:        Optional[str] = Field(None, max_length=100)
    income_range:    Optional[str] = Field(None, max_length=50)

    wants_children:         Optional[bool] = None
    num_children_desired:   Optional[str]  = None
    children_schooling:     Optional[str]  = None
    hajj_timeline:          Optional[str]  = None
    wants_hijra:            Optional[bool] = None
    hijra_country:          Optional[str]  = None
    islamic_finance_stance: Optional[str]  = None
    wife_working_stance:    Optional[str]  = None

    min_age:             Optional[int]       = Field(None, ge=18, le=80)
    max_age:             Optional[int]       = Field(None, ge=18, le=80)
    preferred_countries: Optional[List[str]] = None
    max_distance_km:     Optional[int]       = Field(None, ge=1, le=20000)

    @field_validator(
        "first_name", "last_name", "display_name", "bio", "bio_ar",
        "city", "occupation", "employer", "education_level", "field_of_study",
        "quran_level", "hijra_country",
        mode="before",
    )
    @classmethod
    def sanitize_strings(cls, v: Optional[str]) -> Optional[str]:
        return sanitize_text(v) if v else v


# ─────────────────────────────────────────────
# FAMILY — CREATE / UPDATE
# ─────────────────────────────────────────────

class FamilyUpsertRequest(BaseModel):
    """Create or update the family profile section."""

    family_origin:      Optional[str] = Field(None, max_length=100)
    family_type:        Optional[str] = Field(None, max_length=50)
    num_siblings:       Optional[int] = Field(None, ge=0, le=20)
    family_religiosity: Optional[str] = Field(None, max_length=50)
    father_occupation:  Optional[str] = Field(None, max_length=100)
    mother_occupation:  Optional[str] = Field(None, max_length=100)

    family_description:    Optional[str] = Field(None, max_length=1000)
    family_description_ar: Optional[str] = Field(None, max_length=1000)
    family_values:         Optional[str] = Field(None, max_length=500)

    # Family trivia for games (list of Q&A dicts)
    family_trivia: Optional[List[dict]] = None

    living_arrangement: Optional[str] = Field(None, max_length=50)
    family_involvement: Optional[str] = Field(None, max_length=50)

    @field_validator(
        "family_origin", "family_type", "family_religiosity",
        "father_occupation", "mother_occupation",
        "family_description", "family_description_ar", "family_values",
        mode="before",
    )
    @classmethod
    def sanitize_strings(cls, v: Optional[str]) -> Optional[str]:
        return sanitize_text(v) if v else v


# ─────────────────────────────────────────────
# SIFR ASSESSMENT
# ─────────────────────────────────────────────

class SifrAssessmentRequest(BaseModel):
    """Submit Sifr Islamic personality assessment answers."""
    answers: dict = Field(..., description="Question ID → answer mapping")

    @field_validator("answers")
    @classmethod
    def validate_answers(cls, v: dict) -> dict:
        if len(v) < 15:
            raise ValueError("Assessment requires at least 15 answers")
        return v


# ─────────────────────────────────────────────
# SEARCH PREFERENCES
# ─────────────────────────────────────────────

class SearchPreferencesRequest(BaseModel):
    min_age:             int             = Field(22, ge=18, le=80)
    max_age:             int             = Field(40, ge=18, le=80)
    preferred_countries: List[str]       = Field(default_factory=list)
    max_distance_km:     Optional[int]   = None
    madhab_preference:   Optional[str]   = None
    min_prayer_freq:     Optional[str]   = None

    @model_validator(mode="after")
    def validate_ages(self) -> "SearchPreferencesRequest":
        if self.min_age > self.max_age:
            raise ValueError("min_age must be <= max_age")
        return self


# ─────────────────────────────────────────────
# RESPONSES
# ─────────────────────────────────────────────

class FamilyResponse(BaseModel):
    id: UUID
    family_origin:      Optional[str]
    family_type:        Optional[str]
    num_siblings:       Optional[int]
    family_religiosity: Optional[str]
    father_occupation:  Optional[str]
    mother_occupation:  Optional[str]
    family_description:    Optional[str]
    family_description_ar: Optional[str]
    family_values:         Optional[str]
    living_arrangement:    Optional[str]
    family_involvement:    Optional[str]
    updated_at: datetime

    model_config = {"from_attributes": True}


class ProfileResponse(BaseModel):
    """Full profile — returned to the profile owner."""

    id: UUID
    user_id: UUID

    # Basic
    first_name:   str
    last_name:    str
    display_name: Optional[str]
    date_of_birth: Optional[datetime]
    city:        Optional[str]
    country:     Optional[str]
    nationality: Optional[str]
    languages:   Optional[List[str]]
    age:         Optional[int] = None   # computed

    # Biography
    bio:    Optional[str]
    bio_ar: Optional[str]

    # Media
    photo_url:       Optional[str]
    photos:          Optional[List[str]]
    voice_intro_url: Optional[str]

    # Islamic identity
    madhab:           Optional[MadhabChoice]
    prayer_frequency: Optional[PrayerFrequency]
    hijab_stance:     Optional[HijabStance]
    quran_level:      Optional[str]
    is_revert:        bool
    revert_year:      Optional[int]

    # Education & career
    education_level: Optional[str]
    field_of_study:  Optional[str]
    occupation:      Optional[str]
    employer:        Optional[str]
    income_range:    Optional[str]

    # Life goals
    wants_children:         Optional[bool]
    num_children_desired:   Optional[str]
    children_schooling:     Optional[str]
    hajj_timeline:          Optional[str]
    wants_hijra:            Optional[bool]
    hijra_country:          Optional[str]
    islamic_finance_stance: Optional[str]
    wife_working_stance:    Optional[str]

    # Personality
    sifr_scores:      Optional[dict]
    love_language:    Optional[str]
    priority_ranking: Optional[List[str]]

    # Trust
    mosque_verified:  bool
    scholar_endorsed: bool
    trust_score:      int

    # Search prefs
    min_age:             int
    max_age:             int
    preferred_countries: Optional[List[str]]
    max_distance_km:     Optional[int]

    # Timestamps
    created_at: datetime
    updated_at: datetime

    # Nested
    family: Optional[FamilyResponse] = None

    model_config = {"from_attributes": True}

    @model_validator(mode="after")
    def compute_age(self) -> "ProfileResponse":
        if self.date_of_birth:
            from datetime import timezone
            dob = self.date_of_birth.replace(
                tzinfo=self.date_of_birth.tzinfo or timezone.utc
            )
            self.age = int(
                (datetime.now(timezone.utc) - dob).days / 365.25
            )
        return self


class PublicProfileResponse(BaseModel):
    """
    Profile as seen by other users.
    Photos blurred, last name hidden, employer hidden.
    """

    id: UUID
    user_id: UUID

    first_name:   str
    last_name_initial: str = ""    # "A." not "Ahmed"
    display_name: Optional[str]
    age:          Optional[int]
    city:         Optional[str]
    country:      Optional[str]
    languages:    Optional[List[str]]

    bio:    Optional[str]
    bio_ar: Optional[str]

    # Media — blurred until mutual interest
    photo_url:       Optional[str] = None   # None until mutual interest
    voice_intro_url: Optional[str]          # always available

    # Islamic identity
    madhab:           Optional[MadhabChoice]
    prayer_frequency: Optional[PrayerFrequency]
    hijab_stance:     Optional[HijabStance]
    quran_level:      Optional[str]
    is_revert:        bool

    # Goals (summary only)
    wants_children:       Optional[bool]
    num_children_desired: Optional[str]
    wants_hijra:          Optional[bool]

    # Trust badges
    mosque_verified:  bool
    scholar_endorsed: bool
    trust_score:      int

    # Education (no employer for privacy)
    education_level: Optional[str]
    occupation:      Optional[str]

    # Compatibility score — injected by matching service
    deen_score: Optional[float] = None

    model_config = {"from_attributes": True}

    @model_validator(mode="after")
    def set_last_name_initial(self) -> "PublicProfileResponse":
        # Only show first letter of last name for privacy
        # Full name revealed only after wali-approved match
        return self


class PhotoUploadResponse(BaseModel):
    photo_url:  str
    message:    str
    trust_score: int


class VoiceUploadResponse(BaseModel):
    voice_intro_url: str
    duration_seconds: Optional[float]
    message: str


class ProfileCompletionResponse(BaseModel):
    """Shows profile completion percentage and what's missing."""
    completion_pct:  int
    trust_score:     int
    missing_fields:  List[str]
    next_suggestion: str
