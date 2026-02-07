"""
RizzMePlease API - Auth Routes
"""

from typing import Optional

import structlog
from fastapi import APIRouter

from src.middleware.auth import create_access_token
from src.models import AuthResponse, CreateUserRequest
from src.services.database import db

logger = structlog.get_logger()
router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/anonymous", response_model=AuthResponse)
async def create_anonymous_user(
    request: Optional[CreateUserRequest] = None,
) -> AuthResponse:
    """
    Create an anonymous user and return access token.
    
    This allows the app to work without requiring email/password signup.
    """
    device_id = request.device_id if request else None
    
    # Create user in database
    user = await db.create_anonymous_user(device_id=device_id)
    
    # Generate JWT
    token = create_access_token(user_id=user["id"], is_anonymous=True)
    
    logger.info("anonymous_user_created", user_id=user["id"])
    
    return AuthResponse(
        success=True,
        data={
            "access_token": token,
            "token_type": "bearer",
            "user_id": user["id"],
        }
    )
