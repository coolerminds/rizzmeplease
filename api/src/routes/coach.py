"""
RizzMePlease API - Coach Routes
"""

from datetime import datetime

import structlog
from fastapi import APIRouter, HTTPException, Request, status

from src.middleware import CurrentUser, RateLimited
from src.models import (
    CoachAnalysisData,
    CoachAnalysisResponse,
    CoachAnalyzeRequest,
)
from src.services.ai_service import AIServiceError, ai_service
from src.services.database import db

logger = structlog.get_logger()
router = APIRouter(prefix="/coach", tags=["coach"])


@router.post("/analyze", response_model=CoachAnalysisResponse, status_code=status.HTTP_201_CREATED)
async def analyze_conversation(
    request: CoachAnalyzeRequest,
    raw_request: Request,
    user: CurrentUser,
    _rate_limit: RateLimited,
) -> CoachAnalysisResponse:
    """
    Analyze a conversation and return strategic insights.
    
    Returns patterns, opportunities, and an overall score.
    """
    request_id = getattr(raw_request.state, "request_id", None)

    logger.info(
        "coach_analysis_requested",
        request_id=request_id,
        user_id=user.user_id,
        message_count=len(request.conversation.messages),
    )

    try:
        # Generate insights using AI service
        insights, overall_score = await ai_service.analyze_conversation(
            conversation=request.conversation,
            context=request.context,
            request_id=request_id,
        )

        # Save to database
        analysis_id = await db.save_coach_analysis(
            conversation_id="temp_" + request.idempotency_key,  # No conversation saved
            insights=insights,
            overall_score=overall_score,
            prompt_version=ai_service.prompt_version,
        )

        logger.info(
            "coach_analysis_completed",
            request_id=request_id,
            user_id=user.user_id,
            analysis_id=analysis_id,
            insight_count=len(insights),
            overall_score=overall_score,
        )

        return CoachAnalysisResponse(
            success=True,
            data=CoachAnalysisData(
                analysis_id=analysis_id,
                insights=insights,
                overall_score=overall_score,
                created_at=datetime.utcnow(),
            ),
        )

    except AIServiceError as ai_error:
        logger.error(
            "coach_analysis_failed",
            request_id=request_id,
            user_id=user.user_id,
            code=ai_error.code,
            status_code=ai_error.status_code,
            provider_status=ai_error.provider_status,
            error=ai_error.message,
        )
        raise HTTPException(
            status_code=ai_error.status_code,
            detail={
                "code": ai_error.code,
                "message": ai_error.message,
                "request_id": request_id,
            },
        )

    except Exception as e:
        logger.error(
            "coach_analysis_failed",
            request_id=request_id,
            user_id=user.user_id,
            error=str(e),
        )
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail={
                "code": "AI_ERROR",
                "message": "Failed to analyze conversation. Please try again.",
                "request_id": request_id,
            },
        )
