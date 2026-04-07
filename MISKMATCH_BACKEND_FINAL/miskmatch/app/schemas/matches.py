"""
MiskMatch — Match Schemas (Pydantic v2)
Request/response models for all match endpoints.
"""

from datetime import datetime
from typing import Optional, List
from uuid import UUID

from pydantic import BaseModel, Field, model_validator

from app.models.models import MatchStatus, Gender


# ─────────────────────────────────────────────
# REQUESTS
# ─────────────────────────────────────────────

class ExpressInterestRequest(BaseModel):
    receiver_id: UUID
    message: str = Field(
        ...,
        min_length=20,
        max_length=500,
        description="A respectful, intentional message. Minimum 20 characters.",
    )


class RespondToInterestRequest(BaseModel):
    accept: bool
    message: Optional[str] = Field(
        None,
        max_length=500,
        description="Optional response message",
    )


class WaliDecisionRequest(BaseModel):
    approved: bool
    note: Optional[str] = Field(
        None,
        max_length=300,
        description="Optional note for the family record",
    )


class CloseMatchRequest(BaseModel):
    reason: str = Field(
        ...,
        max_length=100,
        description="Reason for closing the match",
    )


# ─────────────────────────────────────────────
# NESTED RESPONSE PARTS
# ─────────────────────────────────────────────

class MatchProfileSummary(BaseModel):
    """Minimal profile summary embedded in match cards."""
    user_id:         UUID
    first_name:      str
    last_name_initial: str
    age:             Optional[int]
    city:            Optional[str]
    country:         Optional[str]
    photo_url:       Optional[str]     # None until mutual
    voice_intro_url: Optional[str]
    madhab:          Optional[str]
    prayer_frequency: Optional[str]
    mosque_verified: bool
    scholar_endorsed: bool
    trust_score:     int
    deen_score:      Optional[float]   # compatibility score
    model_config = {"from_attributes": True}


class WaliStatusSummary(BaseModel):
    """Wali approval status for both sides of a match."""
    sender_wali_approved:   Optional[bool]
    receiver_wali_approved: Optional[bool]
    both_approved:          bool = False

    @model_validator(mode="after")
    def compute_both(self) -> "WaliStatusSummary":
        self.both_approved = (
            self.sender_wali_approved is True
            and self.receiver_wali_approved is True
        )
        return self


# ─────────────────────────────────────────────
# MATCH RESPONSES
# ─────────────────────────────────────────────

class MatchResponse(BaseModel):
    id:          UUID
    status:      MatchStatus
    created_at:  datetime
    updated_at:  datetime

    # The other person in the match
    other_profile:     Optional[MatchProfileSummary] = None

    # Messages
    sender_message:    Optional[str]
    receiver_response: Optional[str]

    # Wali
    wali_status: Optional[WaliStatusSummary] = None

    # Compatibility
    compatibility_score:    Optional[float]
    compatibility_breakdown: Optional[dict]

    # Timeline
    became_mutual_at: Optional[datetime]
    nikah_date:       Optional[datetime]

    model_config = {"from_attributes": True}


class DiscoveryProfileResponse(BaseModel):
    """A single profile card in the discovery feed."""
    user_id:        UUID
    first_name:     str
    last_name_initial: str
    age:            Optional[int]
    city:           Optional[str]
    country:        Optional[str]
    photo_url:      Optional[str]      # always None in discovery (blurred)
    voice_intro_url: Optional[str]
    bio:            Optional[str]
    madhab:         Optional[str]
    prayer_frequency: Optional[str]
    hijab_stance:   Optional[str]
    quran_level:    Optional[str]
    occupation:     Optional[str]
    education_level: Optional[str]
    wants_children: Optional[bool]
    wants_hijra:    Optional[bool]
    is_revert:      bool
    mosque_verified: bool
    scholar_endorsed: bool
    trust_score:    int
    deen_score:     float              # compatibility score 0-100
    already_interested: bool = False   # did I already express interest?
    model_config = {"from_attributes": True}


class DiscoveryFeedResponse(BaseModel):
    profiles:    List[DiscoveryProfileResponse]
    total:       int
    page:        int
    page_size:   int
    has_more:    bool


class MatchListResponse(BaseModel):
    matches:  List[MatchResponse]
    total:    int
    page:     int
    has_more: bool


class InterestSentResponse(BaseModel):
    match_id:   UUID
    status:     MatchStatus
    message:    str
    wali_notified: bool


class MatchActivatedResponse(BaseModel):
    match_id:      UUID
    status:        MatchStatus
    message:       str
    games_unlocked: List[str]
    first_prompt:  str
