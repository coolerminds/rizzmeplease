"""
RizzMePlease API - History Routes
"""

import math
from typing import Optional

import structlog
from fastapi import APIRouter, Query

from src.middleware import CurrentUser
from src.models import (
    Goal,
    HistoryData,
    HistoryResponse,
    Outcome,
    Pagination,
)
from src.services.database import db

logger = structlog.get_logger()
router = APIRouter(prefix="/history", tags=["history"])


@router.get("", response_model=HistoryResponse)
async def get_history(
    user: CurrentUser,
    page: int = Query(default=1, ge=1, description="Page number"),
    limit: int = Query(default=20, ge=1, le=50, description="Items per page"),
    outcome: Optional[Outcome] = Query(default=None, description="Filter by outcome"),
    goal: Optional[Goal] = Query(default=None, description="Filter by goal"),
) -> HistoryResponse:
    """
    Get paginated conversation history for the current user.
    
    Supports filtering by outcome and goal.
    """
    logger.info(
        "history_requested",
        user_id=user.user_id,
        page=page,
        limit=limit,
        outcome=outcome.value if outcome else None,
        goal=goal.value if goal else None,
    )

    items, total = await db.get_user_history(
        user_id=user.user_id,
        page=page,
        limit=limit,
        outcome_filter=outcome,
        goal_filter=goal,
    )

    total_pages = math.ceil(total / limit) if total > 0 else 1

    return HistoryResponse(
        success=True,
        data=HistoryData(
            items=items,
            pagination=Pagination(
                page=page,
                limit=limit,
                total_items=total,
                total_pages=total_pages,
            ),
        ),
    )
