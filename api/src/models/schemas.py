"""
RizzMePlease API - Pydantic Models
"""

from datetime import datetime
from enum import Enum
from typing import Optional
from uuid import UUID, uuid4

from pydantic import BaseModel, Field, field_validator


# ============================================================================
# Enums
# ============================================================================


class Goal(str, Enum):
    GET_REPLY = "get_reply"
    ASK_MEETUP = "ask_meetup"
    SET_BOUNDARY = "set_boundary"


class Tone(str, Enum):
    FRIENDLY = "friendly"
    DIRECT = "direct"
    WARM = "warm"
    CONFIDENT = "confident"


class RelationshipType(str, Enum):
    FRIEND = "friend"
    STRANGER = "stranger"
    PROFESSIONAL = "professional"
    DATING = "dating"


class Outcome(str, Enum):
    WORKED = "worked"
    NO_RESPONSE = "no_response"
    NEGATIVE = "negative"
    SKIPPED = "skipped"


class InsightType(str, Enum):
    PATTERN = "pattern"
    OPPORTUNITY = "opportunity"
    STRENGTH = "strength"


class InsightPriority(str, Enum):
    HIGH = "high"
    MEDIUM = "medium"
    LOW = "low"


# ============================================================================
# Request Models
# ============================================================================


class MessageData(BaseModel):
    """Individual message in a conversation."""

    sender: str = Field(..., description="Message sender: 'you' or 'them'")
    text: str = Field(..., min_length=1, max_length=500)
    timestamp: Optional[datetime] = None


class ConversationData(BaseModel):
    """Conversation data for analysis."""

    messages: list[MessageData] = Field(..., min_length=2, max_length=50)


class SuggestionRequest(BaseModel):
    """Request body for suggestion generation."""

    conversation: ConversationData
    goal: Goal
    tone: Tone
    relationship_type: Optional[RelationshipType] = None
    thread_context: Optional[ConversationData] = None
    context: Optional[str] = Field(None, max_length=500)
    idempotency_key: str = Field(default_factory=lambda: str(uuid4()))

    @field_validator("conversation")
    @classmethod
    def validate_conversation(cls, v: ConversationData) -> ConversationData:
        if len(v.messages) < 2:
            raise ValueError("Conversation must have at least 2 messages")
        return v


class CoachAnalyzeRequest(BaseModel):
    """Request body for coach analysis."""

    conversation: ConversationData
    context: Optional[str] = Field(None, max_length=500)
    idempotency_key: str = Field(default_factory=lambda: str(uuid4()))


class FeedbackRequest(BaseModel):
    """Request body for feedback submission."""

    suggestion_set_id: str
    suggestion_id: str
    outcome: Outcome
    follow_up_text: Optional[str] = Field(None, max_length=5000)
    notes: Optional[str] = Field(None, max_length=500)


# ============================================================================
# Response Models
# ============================================================================


class Suggestion(BaseModel):
    """Generated suggestion."""

    id: str
    rank: int
    text: str
    rationale: str
    confidence_score: float = Field(ge=0, le=1)


class SuggestionResponseData(BaseModel):
    """Suggestion response data."""

    suggestion_set_id: str
    suggestions: list[Suggestion]
    conversation_id: str
    created_at: datetime


class SuggestionResponse(BaseModel):
    """Full suggestion API response."""

    success: bool = True
    data: SuggestionResponseData


class Insight(BaseModel):
    """Coach insight."""

    type: InsightType
    title: str
    description: str
    priority: InsightPriority


class CoachAnalysisData(BaseModel):
    """Coach analysis response data."""

    analysis_id: str
    insights: list[Insight]
    overall_score: int = Field(ge=0, le=100)
    created_at: datetime


class CoachAnalysisResponse(BaseModel):
    """Full coach analysis API response."""

    success: bool = True
    data: CoachAnalysisData


class FeedbackResponseData(BaseModel):
    """Feedback response data."""

    feedback_id: str
    recorded_at: datetime


class FeedbackResponse(BaseModel):
    """Full feedback API response."""

    success: bool = True
    data: FeedbackResponseData


class HistoryItem(BaseModel):
    """Single history item."""

    conversation_id: str
    preview: str
    goal: Goal
    tone: Tone
    outcome: Optional[Outcome] = None
    created_at: datetime
    suggestion_count: int


class Pagination(BaseModel):
    """Pagination info."""

    page: int
    limit: int
    total_items: int
    total_pages: int


class HistoryData(BaseModel):
    """History response data."""

    items: list[HistoryItem]
    pagination: Pagination


class HistoryResponse(BaseModel):
    """Full history API response."""

    success: bool = True
    data: HistoryData


class DemoHistoryItem(BaseModel):
    """Sample history item for client-side demo hydration."""

    id: str
    vibe: str
    relationship: str
    context: str
    transcript: str
    reply: str
    created_at: datetime


class DemoHistoryData(BaseModel):
    """Demo history response data."""

    items: list[DemoHistoryItem]


class DemoHistoryResponse(BaseModel):
    """Full demo history API response."""

    success: bool = True
    data: DemoHistoryData


# ============================================================================
# Error Models
# ============================================================================


class ErrorDetail(BaseModel):
    """Error detail."""

    code: str
    message: str
    field: Optional[str] = None
    request_id: Optional[str] = None


class ErrorResponse(BaseModel):
    """Error API response."""

    success: bool = False
    error: ErrorDetail


# ============================================================================
# Auth Models
# ============================================================================


class TokenData(BaseModel):
    """JWT token payload."""

    user_id: str
    is_anonymous: bool = True
    exp: datetime


class CreateUserRequest(BaseModel):
    """Request to create anonymous user."""

    device_id: Optional[str] = None


class AuthResponse(BaseModel):
    """Auth response with token."""

    success: bool = True
    data: dict  # Contains access_token, token_type, user_id
