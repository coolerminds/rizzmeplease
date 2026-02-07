"""
RizzMePlease API - Feedback Routes
"""

from datetime import datetime

import structlog
from fastapi import APIRouter, HTTPException, status

from src.middleware import CurrentUser
from src.models import (
    FeedbackRequest,
    FeedbackResponse,
    FeedbackResponseData,
)
from src.services.database import db

logger = structlog.get_logger()
router = APIRouter(prefix="/feedback", tags=["feedback"])


@router.post("", response_model=FeedbackResponse, status_code=status.HTTP_200_OK)
async def submit_feedback(
    request: FeedbackRequest,
    user: CurrentUser,
) -> FeedbackResponse:
    """
    Submit outcome feedback for a used suggestion.
    
    This helps improve future suggestions and powers Coach Insights.
    """
    logger.info(
        "feedback_submitted",
        user_id=user.user_id,
        suggestion_set_id=request.suggestion_set_id,
        suggestion_id=request.suggestion_id,
        outcome=request.outcome.value,
    )

    try:
        # Verify suggestion exists and belongs to user
        suggestion = await db.get_suggestion(request.suggestion_id)
        if not suggestion:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={
                    "code": "NOT_FOUND",
                    "message": "Suggestion not found",
                },
            )

        # Save feedback
        feedback_id = await db.save_feedback(
            suggestion_id=request.suggestion_id,
            outcome=request.outcome,
            follow_up_text=request.follow_up_text,
            notes=request.notes,
        )

        logger.info(
            "feedback_saved",
            user_id=user.user_id,
            feedback_id=feedback_id,
        )

        return FeedbackResponse(
            success=True,
            data=FeedbackResponseData(
                feedback_id=feedback_id,
                recorded_at=datetime.utcnow(),
            ),
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(
            "feedback_failed",
            user_id=user.user_id,
            error=str(e),
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={
                "code": "SERVER_ERROR",
                "message": "Failed to save feedback. Please try again.",
            },
        )
