"""
RizzMePlease API - History Routes
"""

import math
from datetime import datetime, timedelta
from typing import Optional

import structlog
from fastapi import APIRouter, Query

from src.middleware import CurrentUser
from src.models import (
    DemoHistoryData,
    DemoHistoryItem,
    DemoHistoryResponse,
    Goal,
    HistoryData,
    HistoryResponse,
    Outcome,
    Pagination,
)
from src.services.database import db

logger = structlog.get_logger()
router = APIRouter(prefix="/history", tags=["history"])


@router.get("/demo", response_model=DemoHistoryResponse)
async def get_demo_history() -> DemoHistoryResponse:
    """Return deterministic demo history for UI bootstrap/testing."""

    now = datetime.utcnow()
    items = [
        DemoHistoryItem(
            id="demo_friend_chill",
            vibe="chill",
            relationship="friend",
            context="Weekend plans, keep it casual.",
            transcript="Them: Hey! Are you free this weekend?\nYou: Let me check...",
            reply="Sounds good. Want to keep it low-key and grab coffee?",
            created_at=now - timedelta(days=2),
        ),
        DemoHistoryItem(
            id="demo_work_classy",
            vibe="classy",
            relationship="work",
            context="Professional follow-up with clear timeline.",
            transcript="Them: Can you send the revised deck today?\nYou: I can send an update this afternoon.",
            reply="Absolutely. I will send the revised deck by 3 PM with notes.",
            created_at=now - timedelta(days=1, hours=5),
        ),
        DemoHistoryItem(
            id="demo_dating_flirty",
            vibe="flirty",
            relationship="dating",
            context="Playful but respectful.",
            transcript="Them: Last night was fun.\nYou: I had a great time too.",
            reply="I liked the vibe too. Want to do round two this week?",
            created_at=now - timedelta(hours=18),
        ),
    ]

    return DemoHistoryResponse(success=True, data=DemoHistoryData(items=items))


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
