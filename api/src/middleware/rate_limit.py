"""
RizzMePlease API - Rate Limiting Middleware
"""

from datetime import datetime
from typing import Annotated, Optional

import structlog
from fastapi import Depends, HTTPException, Request, status

from src.config import get_settings
from src.middleware.auth import CurrentUser

logger = structlog.get_logger()

# In-memory rate limiting (use Redis in production)
_rate_limit_store: dict[str, dict] = {}


class RateLimiter:
    """Simple in-memory rate limiter (use Redis in production)."""

    def __init__(
        self,
        requests_per_minute: Optional[int] = None,
        requests_per_day: Optional[int] = None,
    ):
        settings = get_settings()
        self.requests_per_minute = requests_per_minute or settings.rate_limit_requests_per_minute
        self.requests_per_day = requests_per_day or settings.rate_limit_requests_per_day

    async def check_rate_limit(self, user_id: str) -> None:
        """Check if user is within rate limits."""

        now = datetime.utcnow()
        user_data = _rate_limit_store.get(user_id, {
            "minute_count": 0,
            "minute_reset": now,
            "day_count": 0,
            "day_reset": now,
        })

        # Reset minute counter if needed
        if (now - user_data["minute_reset"]).total_seconds() > 60:
            user_data["minute_count"] = 0
            user_data["minute_reset"] = now

        # Reset day counter if needed
        if (now - user_data["day_reset"]).total_seconds() > 86400:
            user_data["day_count"] = 0
            user_data["day_reset"] = now

        # Check limits
        if user_data["minute_count"] >= self.requests_per_minute:
            logger.warning("rate_limit_exceeded", user_id=user_id, type="minute")
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail={
                    "code": "RATE_LIMITED",
                    "message": "Too many requests. Please wait a moment.",
                },
                headers={"Retry-After": "60"},
            )

        if user_data["day_count"] >= self.requests_per_day:
            logger.warning("rate_limit_exceeded", user_id=user_id, type="day")
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail={
                    "code": "RATE_LIMITED",
                    "message": "Daily limit reached. Try again tomorrow.",
                },
                headers={"Retry-After": "86400"},
            )

        # Increment counters
        user_data["minute_count"] += 1
        user_data["day_count"] += 1
        _rate_limit_store[user_id] = user_data


# Dependency for rate limiting
async def check_rate_limit(user: CurrentUser) -> None:
    """Rate limit dependency for routes."""
    limiter = RateLimiter()
    await limiter.check_rate_limit(user.user_id)


RateLimited = Annotated[None, Depends(check_rate_limit)]
