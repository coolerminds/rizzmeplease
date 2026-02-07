"""
RizzMePlease API - User Routes
"""

import structlog
from fastapi import APIRouter, HTTPException, status

from src.middleware import CurrentUser
from src.services.database import db

logger = structlog.get_logger()
router = APIRouter(prefix="/user", tags=["user"])


@router.delete("/data", status_code=status.HTTP_204_NO_CONTENT)
async def delete_user_data(user: CurrentUser) -> None:
    """
    Delete all user data (GDPR compliant).
    
    This soft-deletes the user and all associated data.
    Data is permanently removed within 72 hours.
    """
    logger.info("data_deletion_requested", user_id=user.user_id)

    try:
        await db.delete_user_data(user.user_id)
        logger.info("data_deletion_completed", user_id=user.user_id)

    except Exception as e:
        logger.error(
            "data_deletion_failed",
            user_id=user.user_id,
            error=str(e),
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={
                "code": "SERVER_ERROR",
                "message": "Failed to delete data. Please contact support.",
            },
        )
