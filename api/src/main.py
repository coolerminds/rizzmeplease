"""
RizzMePlease API - Main Application Entry Point
"""

from contextlib import asynccontextmanager
from typing import AsyncGenerator
from uuid import uuid4

import structlog
from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from src.config import get_settings
from src.routes import (
    auth_router,
    coach_router,
    feedback_router,
    history_router,
    suggestions_router,
    user_router,
)

# Configure structured logging
structlog.configure(
    processors=[
        structlog.stdlib.filter_by_level,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.JSONRenderer(),
    ],
    wrapper_class=structlog.stdlib.BoundLogger,
    context_class=dict,
    logger_factory=structlog.stdlib.LoggerFactory(),
    cache_logger_on_first_use=True,
)

logger = structlog.get_logger()


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    """Application lifespan handler."""
    settings = get_settings()
    logger.info(
        "app_starting",
        environment=settings.environment,
        debug=settings.debug,
    )
    yield
    logger.info("app_shutdown")


# Create FastAPI app
app = FastAPI(
    title="RizzMePlease API",
    description="Backend API for the RizzMePlease iOS text coaching app",
    version="1.0.0",
    docs_url="/docs" if get_settings().debug else None,
    redoc_url="/redoc" if get_settings().debug else None,
    lifespan=lifespan,
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=get_settings().cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ============================================================================
# Exception Handlers
# ============================================================================


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(
    request: Request,
    exc: RequestValidationError,
) -> JSONResponse:
    """Handle Pydantic validation errors."""
    errors = exc.errors()
    first_error = errors[0] if errors else {}

    return JSONResponse(
        status_code=status.HTTP_400_BAD_REQUEST,
        content={
            "success": False,
            "error": {
                "code": "VALIDATION_ERROR",
                "message": first_error.get("msg", "Invalid request"),
                "field": ".".join(str(x) for x in first_error.get("loc", [])),
                "request_id": str(uuid4()),
            },
        },
    )


@app.exception_handler(Exception)
async def general_exception_handler(
    request: Request,
    exc: Exception,
) -> JSONResponse:
    """Handle unexpected exceptions."""
    request_id = str(uuid4())
    logger.error(
        "unhandled_exception",
        request_id=request_id,
        path=request.url.path,
        error=str(exc),
        exc_info=True,
    )

    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "success": False,
            "error": {
                "code": "SERVER_ERROR",
                "message": "An unexpected error occurred",
                "request_id": request_id,
            },
        },
    )


# ============================================================================
# Request Middleware
# ============================================================================


@app.middleware("http")
async def add_request_context(request: Request, call_next):
    """Add request ID and logging context to each request."""
    request_id = request.headers.get("X-Request-ID", str(uuid4()))
    request.state.request_id = request_id

    # Log request
    logger.info(
        "request_started",
        request_id=request_id,
        method=request.method,
        path=request.url.path,
    )

    response = await call_next(request)

    # Add request ID to response
    response.headers["X-Request-ID"] = request_id

    logger.info(
        "request_completed",
        request_id=request_id,
        status_code=response.status_code,
    )

    return response


# ============================================================================
# Routes
# ============================================================================


@app.get("/health")
async def health_check() -> dict:
    """Health check endpoint."""
    return {"status": "healthy", "version": "1.0.0"}


@app.get("/api/health")
async def api_health_check() -> dict:
    """Health check alias for reverse proxies that route under /api."""
    return {"status": "healthy", "version": "1.0.0"}


# Include routers
app.include_router(auth_router, prefix="/api/v1")
app.include_router(suggestions_router, prefix="/api/v1")
app.include_router(coach_router, prefix="/api/v1")
app.include_router(feedback_router, prefix="/api/v1")
app.include_router(history_router, prefix="/api/v1")
app.include_router(user_router, prefix="/api/v1")


if __name__ == "__main__":
    import uvicorn

    settings = get_settings()
    uvicorn.run(
        "src.main:app",
        host="0.0.0.0",
        port=8000,
        reload=settings.debug,
        log_level=settings.log_level.lower(),
    )
