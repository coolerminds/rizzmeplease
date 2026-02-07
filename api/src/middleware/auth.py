"""
RizzMePlease API - Authentication Middleware
"""

from datetime import datetime, timedelta
from typing import Annotated, Optional
from uuid import uuid4

import structlog
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt

from src.config import get_settings
from src.models import TokenData
from src.services.database import db

logger = structlog.get_logger()
security = HTTPBearer(auto_error=False)


def create_access_token(user_id: str, is_anonymous: bool = True) -> str:
    """Create a JWT access token."""
    settings = get_settings()

    expire = datetime.utcnow() + timedelta(hours=settings.jwt_expiration_hours)
    payload = {
        "sub": user_id,
        "is_anonymous": is_anonymous,
        "exp": expire,
        "iat": datetime.utcnow(),
        "jti": str(uuid4()),  # Unique token ID for invalidation
    }

    token = jwt.encode(
        payload,
        settings.jwt_secret,
        algorithm=settings.jwt_algorithm,
    )

    logger.info("token_created", user_id=user_id, is_anonymous=is_anonymous)
    return token


def decode_token(token: str) -> TokenData:
    """Decode and validate a JWT token."""
    settings = get_settings()

    try:
        payload = jwt.decode(
            token,
            settings.jwt_secret,
            algorithms=[settings.jwt_algorithm],
        )

        user_id = payload.get("sub")
        if user_id is None:
            raise JWTError("Missing subject claim")

        return TokenData(
            user_id=user_id,
            is_anonymous=payload.get("is_anonymous", True),
            exp=datetime.fromtimestamp(payload.get("exp", 0)),
        )

    except JWTError as e:
        logger.warning("token_decode_failed", error=str(e))
        raise


async def get_current_user(
    credentials: Annotated[
        Optional[HTTPAuthorizationCredentials],
        Depends(security),
    ],
) -> TokenData:
    """Dependency to get current authenticated user from JWT."""

    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={
                "code": "UNAUTHORIZED",
                "message": "Missing authorization header",
            },
            headers={"WWW-Authenticate": "Bearer"},
        )

    try:
        token_data = decode_token(credentials.credentials)

        # Check token expiration
        if token_data.exp < datetime.utcnow():
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail={
                    "code": "TOKEN_EXPIRED",
                    "message": "Token has expired",
                },
                headers={"WWW-Authenticate": "Bearer"},
            )

        # Update last seen (fire and forget)
        try:
            await db.update_last_seen(token_data.user_id)
        except Exception:
            pass  # Non-critical

        return token_data

    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={
                "code": "INVALID_TOKEN",
                "message": "Invalid authentication token",
            },
            headers={"WWW-Authenticate": "Bearer"},
        )


# Type alias for dependency injection
CurrentUser = Annotated[TokenData, Depends(get_current_user)]
