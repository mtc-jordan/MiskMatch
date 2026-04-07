"""
MiskMatch — Message Schemas (Pydantic v2)
Request/response models for chat and WebSocket events.
"""

from datetime import datetime
from typing import Optional, List, Any
from uuid import UUID

from pydantic import BaseModel, Field, field_validator

from app.models.models import MessageStatus


# ─────────────────────────────────────────────
# REST SCHEMAS
# ─────────────────────────────────────────────

class SendMessageRequest(BaseModel):
    content: str = Field(
        ...,
        min_length=1,
        max_length=2000,
        description="Message text content",
    )
    content_type: str = Field(
        default="text",
        pattern="^(text|audio|image)$",
    )
    media_url: Optional[str] = Field(
        None,
        max_length=500,
        description="S3 URL for audio/image messages",
    )

    @field_validator("content")
    @classmethod
    def no_whitespace_only(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("Message cannot be empty or whitespace only")
        return v.strip()


class MessageResponse(BaseModel):
    id:           UUID
    match_id:     UUID
    sender_id:    UUID
    content:      str
    content_type: str
    media_url:    Optional[str]
    status:       MessageStatus
    created_at:   datetime
    updated_at:   datetime

    # Sender info (lightweight)
    sender_name:  Optional[str] = None

    # Moderation (only visible to admin/wali)
    moderation_passed: Optional[bool] = None

    model_config = {"from_attributes": True}


class MessageListResponse(BaseModel):
    messages:  List[MessageResponse]
    total:     int
    page:      int
    has_more:  bool
    match_id:  UUID


class MarkReadRequest(BaseModel):
    message_ids: List[UUID] = Field(..., min_length=1, max_length=100)


# ─────────────────────────────────────────────
# WEBSOCKET EVENT SCHEMAS
# Events flow over the WS connection as JSON.
# ─────────────────────────────────────────────

class WSEventType:
    """All WebSocket event type strings."""
    # Client → Server
    SEND_MESSAGE   = "send_message"
    MARK_READ      = "mark_read"
    TYPING_START   = "typing_start"
    TYPING_STOP    = "typing_stop"
    PING           = "ping"

    # Server → Client
    NEW_MESSAGE    = "new_message"
    MESSAGE_READ   = "message_read"
    TYPING         = "typing"
    PONG           = "pong"
    ERROR          = "error"
    CONNECTED      = "connected"
    PRESENCE       = "presence"          # online/offline status
    MODERATION     = "moderation_alert"  # message held


class WSEvent(BaseModel):
    """Base WebSocket event envelope."""
    type:    str
    payload: dict = Field(default_factory=dict)


class WSSendMessage(BaseModel):
    """Client sends this to send a chat message over WebSocket."""
    match_id:     UUID
    content:      str = Field(..., min_length=1, max_length=2000)
    content_type: str = Field(default="text", pattern="^(text|audio|image)$")
    media_url:    Optional[str] = None
    client_id:    Optional[str] = None  # client-side idempotency key


class WSNewMessage(BaseModel):
    """Server broadcasts this when a new message arrives."""
    id:           UUID
    match_id:     UUID
    sender_id:    UUID
    sender_name:  str
    content:      str
    content_type: str
    media_url:    Optional[str]
    created_at:   datetime
    status:       str


class WSTypingEvent(BaseModel):
    """Server broadcasts typing indicator."""
    match_id:  UUID
    user_id:   UUID
    user_name: str
    typing:    bool


class WSPresenceEvent(BaseModel):
    """Server broadcasts presence changes."""
    user_id:   UUID
    online:    bool
    last_seen: Optional[datetime]


# ─────────────────────────────────────────────
# WALI PORTAL SCHEMAS
# ─────────────────────────────────────────────

class WaliConversationSummary(BaseModel):
    """Summary card of a conversation in the Wali portal."""
    match_id:          UUID
    ward_name:         str        # the user the wali is guarding
    other_name:        str        # the match
    last_message:      Optional[str]
    last_message_at:   Optional[datetime]
    unread_count:      int
    match_status:      str
    message_count:     int
    flagged_count:     int        # messages flagged by AI
    model_config = {"from_attributes": True}


class WaliMessageView(BaseModel):
    """Message as seen in wali portal — includes moderation info."""
    id:                UUID
    sender_id:         UUID
    sender_name:       str
    content:           str
    content_type:      str
    status:            MessageStatus
    created_at:        datetime
    moderation_passed: Optional[bool]
    moderation_reason: Optional[str]
    is_flagged:        bool = False
    model_config = {"from_attributes": True}
