"""Routes package."""

from src.routes.auth import router as auth_router
from src.routes.coach import router as coach_router
from src.routes.feedback import router as feedback_router
from src.routes.history import router as history_router
from src.routes.suggestions import router as suggestions_router
from src.routes.user import router as user_router

__all__ = [
    "auth_router",
    "coach_router",
    "feedback_router",
    "history_router",
    "suggestions_router",
    "user_router",
]
