"""
RizzMePlease API - Suggestions Routes
"""

from datetime import datetime

import structlog
from fastapi import APIRouter, HTTPException, status

from src.middleware import CurrentUser, RateLimited
from src.models import (
    SuggestionRequest,
    SuggestionResponse,
    SuggestionResponseData,
)
from src.services.ai_service import ai_service
from src.services.database import db

logger = structlog.get_logger()
router = APIRouter(prefix="/suggestions", tags=["suggestions"])


@router.post("", response_model=SuggestionResponse, status_code=status.HTTP_201_CREATED)
async def generate_suggestions(
    request: SuggestionRequest,
    user: CurrentUser,
    _rate_limit: RateLimited,
) -> SuggestionResponse:
    """
    Generate AI-powered reply suggestions for a conversation.
    
    Returns 3 ranked suggestions with rationale for each.
    """
    logger.info(
        "suggestions_requested",
        user_id=user.user_id,
        goal=request.goal.value,
        tone=request.tone.value,
        message_count=len(request.conversation.messages),
    )

    try:
        # Generate suggestions using AI service
        suggestions = await ai_service.generate_suggestions(
            conversation=request.conversation,
            goal=request.goal,
            tone=request.tone,
            context=request.context,
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
            user_id=user.user_id,
            conversation_id=conversation_id,
            suggestion_set_id=suggestion_set_id,
            count=len(suggestions),
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

    except Exception as e:
        logger.error(
            "suggestions_failed",
            user_id=user.user_id,
            error=str(e),
        )
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail={
                "code": "AI_ERROR",
                "message": "Failed to generate suggestions. Please try again.",
            },
        )
