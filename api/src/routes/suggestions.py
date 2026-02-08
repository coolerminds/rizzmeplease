"""
RizzMePlease API - Suggestions Routes
"""

from datetime import datetime
from uuid import uuid4

import structlog
from fastapi import APIRouter, HTTPException, Request, status

from src.middleware import CurrentUser, RateLimited
from src.models import (
    Goal,
    Suggestion,
    SuggestionRequest,
    SuggestionResponse,
    SuggestionResponseData,
)
from src.services.ai_service import AIServiceError, ai_service
from src.services.database import db

logger = structlog.get_logger()
router = APIRouter(prefix="/suggestions", tags=["suggestions"])

_ALLOWED_SENDERS = {"you", "them"}
_SAFETY_TERMS = {
    "kill",
    "suicide",
    "self harm",
    "hate",
    "abuse",
    "violent",
    "nude",
    "explicit",
}


@router.post("", response_model=SuggestionResponse, status_code=status.HTTP_201_CREATED)
async def generate_suggestions(
    request: SuggestionRequest,
    raw_request: Request,
    user: CurrentUser,
    _rate_limit: RateLimited,
) -> SuggestionResponse:
    """
    Generate AI-powered reply suggestions for a conversation.

    Returns 3 ranked suggestions with rationale for each.
    """
    request_id = getattr(raw_request.state, "request_id", str(uuid4()))

    _validate_request_limits(request)
    _log_safety_signals(request, request_id=request_id, user_id=user.user_id)

    logger.info(
        "suggestions_requested",
        request_id=request_id,
        user_id=user.user_id,
        goal=request.goal.value,
        tone=request.tone.value,
        relationship_type=request.relationship_type.value
        if request.relationship_type
        else None,
        message_count=len(request.conversation.messages),
        thread_message_count=len(request.thread_context.messages)
        if request.thread_context
        else 0,
    )

    fallback_used = False
    try:
        try:
            suggestions = await ai_service.generate_suggestions(
                conversation=request.conversation,
                goal=request.goal,
                tone=request.tone,
                context=request.context,
                relationship_type=request.relationship_type,
                thread_context=request.thread_context,
                request_id=request_id,
            )
        except AIServiceError as ai_error:
            if ai_error.retryable:
                suggestions = _transport_fallback_suggestions(request.goal)
                fallback_used = True
                logger.warning(
                    "suggestions_transport_fallback_used",
                    request_id=request_id,
                    user_id=user.user_id,
                    reason=ai_error.code,
                    provider_status=ai_error.provider_status,
                )
            else:
                raise HTTPException(
                    status_code=ai_error.status_code,
                    detail={
                        "code": ai_error.code,
                        "message": ai_error.message,
                        "request_id": request_id,
                    },
                )

        # Save conversation and suggestions to database
        conversation_id = await db.create_conversation(
            user_id=user.user_id,
            conversation=request.conversation,
            goal=request.goal,
            tone=request.tone,
            context=request.context,
            prompt_version=ai_service.prompt_version,
        )

        suggestion_set_id = await db.save_suggestions(
            conversation_id=conversation_id,
            suggestions=suggestions,
        )

        logger.info(
            "suggestions_generated",
            request_id=request_id,
            user_id=user.user_id,
            conversation_id=conversation_id,
            suggestion_set_id=suggestion_set_id,
            count=len(suggestions),
            fallback_used=fallback_used,
        )

        return SuggestionResponse(
            success=True,
            data=SuggestionResponseData(
                suggestion_set_id=suggestion_set_id,
                suggestions=suggestions,
                conversation_id=conversation_id,
                created_at=datetime.utcnow(),
            ),
        )

    except HTTPException:
        raise
    except Exception as exc:
        logger.error(
            "suggestions_failed",
            request_id=request_id,
            user_id=user.user_id,
            error=str(exc),
        )
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail={
                "code": "AI_ERROR",
                "message": "Failed to generate suggestions. Please try again.",
                "request_id": request_id,
            },
        )


def _validate_request_limits(request: SuggestionRequest) -> None:
    """Apply server-side bounds before hitting the provider."""

    if len(request.conversation.messages) > 50:
        raise _validation_error("conversation.messages supports up to 50 items.")

    for message in request.conversation.messages:
        if message.sender.lower() not in _ALLOWED_SENDERS:
            raise _validation_error("message.sender must be 'you' or 'them'.")
        if not message.text.strip():
            raise _validation_error("message.text cannot be empty.")
        if len(message.text) > 500:
            raise _validation_error("message.text max length is 500.")

    if request.thread_context:
        if len(request.thread_context.messages) > 50:
            raise _validation_error("thread_context.messages supports up to 50 items.")

        for message in request.thread_context.messages:
            if message.sender.lower() not in _ALLOWED_SENDERS:
                raise _validation_error(
                    "thread_context message.sender must be 'you' or 'them'."
                )
            if not message.text.strip():
                raise _validation_error("thread_context message.text cannot be empty.")
            if len(message.text) > 500:
                raise _validation_error(
                    "thread_context message.text max length is 500."
                )

    if request.context and len(request.context) > 500:
        raise _validation_error("context max length is 500.")


def _log_safety_signals(
    request: SuggestionRequest,
    *,
    request_id: str,
    user_id: str,
) -> None:
    """Log soft safety/profanity signals without blocking the request."""

    corpus = " ".join(
        [
            *(msg.text for msg in request.conversation.messages),
            *(
                msg.text
                for msg in request.thread_context.messages
                if request.thread_context
            ),
            request.context or "",
        ]
    ).lower()

    matched_terms = sorted(term for term in _SAFETY_TERMS if term in corpus)
    if matched_terms:
        logger.warning(
            "safety_terms_detected",
            request_id=request_id,
            user_id=user_id,
            matched_terms=matched_terms,
        )
    else:
        logger.info(
            "safety_scan_clean",
            request_id=request_id,
            user_id=user_id,
        )


def _transport_fallback_suggestions(goal: Goal) -> list[Suggestion]:
    """Deterministic fallback suggestions for transport-layer provider failures."""

    if goal == Goal.ASK_MEETUP:
        template = [
            (
                "I have enjoyed this conversation. Want to meet for coffee this week?",
                "Clear ask with low pressure and a specific next step.",
            ),
            (
                "Would you be open to a quick meetup this weekend?",
                "Moves from text to in-person while keeping tone flexible.",
            ),
            (
                "If you are free, we could pick a time and place that works for both of us.",
                "Invites collaboration and avoids pressure.",
            ),
        ]
    elif goal == Goal.SET_BOUNDARY:
        template = [
            (
                "I am not available for that, but I appreciate you reaching out.",
                "Sets a clear boundary while staying respectful.",
            ),
            (
                "I need to pass this time, and I want to be direct about it.",
                "Communicates limits clearly and calmly.",
            ),
            (
                "I am keeping things simple right now, so I cannot commit to this.",
                "Maintains firmness without over-explaining.",
            ),
        ]
    else:
        template = [
            (
                "That makes sense. What part matters most to you right now?",
                "Encourages a response with an open-ended question.",
            ),
            (
                "I am into this conversation. Want to keep it going?",
                "Shows interest and creates easy momentum.",
            ),
            (
                "Thanks for sharing that. I would like to hear a bit more.",
                "Warm acknowledgment that invites continuation.",
            ),
        ]

    return [
        Suggestion(
            id=f"fallback_{uuid4().hex[:8]}",
            rank=index + 1,
            text=text,
            rationale=rationale,
            confidence_score=round(0.75 - (index * 0.05), 2),
        )
        for index, (text, rationale) in enumerate(template)
    ]


def _validation_error(message: str) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST,
        detail={
            "code": "VALIDATION_ERROR",
            "message": message,
        },
    )
