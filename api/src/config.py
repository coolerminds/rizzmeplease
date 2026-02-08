"""
RizzMePlease API - Configuration
"""

from functools import lru_cache
from typing import Optional
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    # OpenAI / xAI (OpenAI-compatible API)
    openai_api_key: Optional[str] = None
    xai_api_key: Optional[str] = None
    openai_model: str = "gpt-4o-mini"
    openai_timeout: int = 30
    openai_base_url: str = "https://api.openai.com/v1"
    xai_base_url: str = "https://api.x.ai/v1"

    # Supabase
    supabase_url: str
    supabase_key: str
    supabase_service_key: str

    # JWT
    jwt_secret: str
    jwt_algorithm: str = "HS256"
    jwt_expiration_hours: int = 24

    # Redis
    redis_url: str = "redis://localhost:6379"

    # App
    environment: str = "development"
    debug: bool = True
    log_level: str = "INFO"
    cors_allow_origins: str = "https://rizzmeow.com,https://www.rizzmeow.com"

    # Rate Limiting
    rate_limit_requests_per_minute: int = 10
    rate_limit_requests_per_day: int = 100

    @property
    def is_production(self) -> bool:
        return self.environment == "production"

    @property
    def ai_api_key(self) -> str:
        """Return configured AI API key, preferring OpenAI when both are set."""
        if self.openai_api_key:
            return self.openai_api_key
        if self.xai_api_key:
            return self.xai_api_key
        raise ValueError("Set OPENAI_API_KEY or XAI_API_KEY in environment.")

    @property
    def ai_base_url(self) -> str:
        """Return API base URL for the selected provider."""
        if self.openai_api_key:
            return self.openai_base_url
        return self.xai_base_url

    @property
    def cors_origins(self) -> list[str]:
        """Return normalized CORS origins with sane local dev defaults."""
        configured = [
            origin.strip()
            for origin in self.cors_allow_origins.split(",")
            if origin.strip()
        ]
        if self.debug:
            configured.extend(
                [
                    "http://localhost:3000",
                    "http://localhost:5173",
                    "http://127.0.0.1:3000",
                    "http://127.0.0.1:5173",
                ]
            )
        return list(dict.fromkeys(configured))


@lru_cache
def get_settings() -> Settings:
    """Get cached settings instance."""
    return Settings()
