"""
RizzMePlease API - Database Service (Supabase)
"""

from datetime import datetime
from typing import Optional
from uuid import uuid4

import structlog
from supabase import acreate_client, AsyncClient

from src.config import get_settings
from src.models import (
    ConversationData,
    Goal,
    HistoryItem,
    Outcome,
    Suggestion,
    Tone,
)

logger = structlog.get_logger()


class DatabaseService:
    """Handles all Supabase database operations."""

    _client: Optional[AsyncClient] = None

    @classmethod
    async def get_client(cls) -> AsyncClient:
        """Get or create async Supabase client."""
        if cls._client is None:
            settings = get_settings()
            cls._client = await acreate_client(
                settings.supabase_url,
                settings.supabase_service_key,
            )
        return cls._client

    # ========================================================================
    # Users
    # ========================================================================

    @classmethod
    async def create_anonymous_user(cls, device_id: Optional[str] = None) -> dict:
        """Create a new anonymous user."""
        client = await cls.get_client()

        user_data = {
            "id": str(uuid4()),
            "is_anonymous": True,
            "preferences": {},
            "created_at": datetime.utcnow().isoformat(),
            "last_seen_at": datetime.utcnow().isoformat(),
        }

        if device_id:
            user_data["preferences"] = {"device_id": device_id}

        result = await client.table("users").insert(user_data).execute()
        logger.info("user_created", user_id=user_data["id"], is_anonymous=True)
        return result.data[0]

    @classmethod
    async def get_user(cls, user_id: str) -> Optional[dict]:
        """Get user by ID."""
        client = await cls.get_client()
        result = await client.table("users").select("*").eq("id", user_id).execute()
        return result.data[0] if result.data else None

    @classmethod
    async def update_last_seen(cls, user_id: str) -> None:
        """Update user's last seen timestamp."""
        client = await cls.get_client()
        await (
            client.table("users")
            .update({"last_seen_at": datetime.utcnow().isoformat()})
            .eq("id", user_id)
            .execute()
        )

    # ========================================================================
    # Conversations
    # ========================================================================

    @classmethod
    async def create_conversation(
        cls,
        user_id: str,
        conversation: ConversationData,
        goal: Goal,
        tone: Tone,
        context: Optional[str],
        prompt_version: str,
    ) -> str:
        """Create a new conversation record."""
        client = await cls.get_client()

        conversation_id = str(uuid4())
        raw_text = "\n".join(
            f"{msg.sender}: {msg.text}" for msg in conversation.messages
        )

        conv_data = {
            "id": conversation_id,
            "user_id": user_id,
            "raw_text": raw_text,
            "goal": goal.value,
            "tone": tone.value,
            "context": context,
            "prompt_version": prompt_version,
            "created_at": datetime.utcnow().isoformat(),
        }

        await client.table("conversations").insert(conv_data).execute()
        logger.info(
            "conversation_created",
            conversation_id=conversation_id,
            goal=goal.value,
            tone=tone.value,
        )
        return conversation_id

    @classmethod
    async def get_conversation(cls, conversation_id: str) -> Optional[dict]:
        """Get conversation by ID."""
        client = await cls.get_client()
        result = (
            await client.table("conversations")
            .select("*")
            .eq("id", conversation_id)
            .execute()
        )
        return result.data[0] if result.data else None

    # ========================================================================
    # Suggestions
    # ========================================================================

    @classmethod
    async def save_suggestions(
        cls,
        conversation_id: str,
        suggestions: list[Suggestion],
    ) -> str:
        """Save generated suggestions to database."""
        client = await cls.get_client()

        suggestion_set_id = f"set_{uuid4().hex[:12]}"

        suggestion_records = [
            {
                "id": sug.id,
                "suggestion_set_id": suggestion_set_id,
                "conversation_id": conversation_id,
                "rank": sug.rank,
                "text": sug.text,
                "rationale": sug.rationale,
                "confidence_score": sug.confidence_score,
                "created_at": datetime.utcnow().isoformat(),
            }
            for sug in suggestions
        ]

        await client.table("suggestions").insert(suggestion_records).execute()
        logger.info(
            "suggestions_saved",
            suggestion_set_id=suggestion_set_id,
            count=len(suggestions),
        )
        return suggestion_set_id

    @classmethod
    async def get_suggestion(cls, suggestion_id: str) -> Optional[dict]:
        """Get suggestion by ID."""
        client = await cls.get_client()
        result = (
            await client.table("suggestions")
            .select("*")
            .eq("id", suggestion_id)
            .execute()
        )
        return result.data[0] if result.data else None

    @classmethod
    async def mark_suggestion_copied(cls, suggestion_id: str) -> None:
        """Mark suggestion as copied."""
        client = await cls.get_client()
        await (
            client.table("suggestions")
            .update({"copied_at": datetime.utcnow().isoformat()})
            .eq("id", suggestion_id)
            .execute()
        )

    # ========================================================================
    # Feedback
    # ========================================================================

    @classmethod
    async def save_feedback(
        cls,
        suggestion_id: str,
        outcome: Outcome,
        follow_up_text: Optional[str],
        notes: Optional[str],
    ) -> str:
        """Save user feedback on a suggestion."""
        client = await cls.get_client()

        feedback_id = f"fb_{uuid4().hex[:12]}"

        feedback_data = {
            "id": feedback_id,
            "suggestion_id": suggestion_id,
            "outcome": outcome.value,
            "follow_up_text": follow_up_text,
            "notes": notes,
            "created_at": datetime.utcnow().isoformat(),
        }

        await client.table("feedback").insert(feedback_data).execute()
        logger.info(
            "feedback_saved",
            feedback_id=feedback_id,
            outcome=outcome.value,
        )
        return feedback_id

    # ========================================================================
    # History
    # ========================================================================

    @classmethod
    async def get_user_history(
        cls,
        user_id: str,
        page: int = 1,
        limit: int = 20,
        outcome_filter: Optional[Outcome] = None,
        goal_filter: Optional[Goal] = None,
    ) -> tuple[list[HistoryItem], int]:
        """Get paginated user conversation history."""
        client = await cls.get_client()

        offset = (page - 1) * limit

        # Build query
        query = (
            client.table("conversations")
            .select("*, suggestions(*), feedback(*)", count="exact")
            .eq("user_id", user_id)
            .is_("deleted_at", "null")
            .order("created_at", desc=True)
        )

        if goal_filter:
            query = query.eq("goal", goal_filter.value)

        query = query.range(offset, offset + limit - 1)
        result = await query.execute()

        items = []
        for conv in result.data:
            # Get outcome from feedback if exists
            outcome = None
            if conv.get("suggestions"):
                for sug in conv["suggestions"]:
                    if sug.get("feedback"):
                        outcome = Outcome(sug["feedback"][0]["outcome"])
                        break

            items.append(
                HistoryItem(
                    conversation_id=conv["id"],
                    preview=conv["raw_text"][:60] + "..."
                    if len(conv["raw_text"]) > 60
                    else conv["raw_text"],
                    goal=Goal(conv["goal"]),
                    tone=Tone(conv["tone"]),
                    outcome=outcome,
                    created_at=datetime.fromisoformat(conv["created_at"]),
                    suggestion_count=len(conv.get("suggestions", [])),
                )
            )

        total = result.count or 0
        return items, total

    # ========================================================================
    # Coach Analyses
    # ========================================================================

    @classmethod
    async def save_coach_analysis(
        cls,
        conversation_id: str,
        insights: list[dict],
        overall_score: int,
        prompt_version: str,
    ) -> str:
        """Save coach analysis results."""
        client = await cls.get_client()

        analysis_id = f"ana_{uuid4().hex[:12]}"

        analysis_data = {
            "id": analysis_id,
            "conversation_id": conversation_id,
            "insights": [i.model_dump() if hasattr(i, "model_dump") else i for i in insights],
            "overall_score": overall_score,
            "prompt_version": prompt_version,
            "created_at": datetime.utcnow().isoformat(),
        }

        await client.table("coach_analyses").insert(analysis_data).execute()
        logger.info("coach_analysis_saved", analysis_id=analysis_id)
        return analysis_id

    # ========================================================================
    # Data Deletion
    # ========================================================================

    @classmethod
    async def delete_user_data(cls, user_id: str) -> None:
        """Soft-delete all user data."""
        client = await cls.get_client()
        deleted_at = datetime.utcnow().isoformat()

        # Soft-delete user
        await (
            client.table("users")
            .update({"deleted_at": deleted_at})
            .eq("id", user_id)
            .execute()
        )

        # Soft-delete conversations (cascade handles rest)
        await (
            client.table("conversations")
            .update({"deleted_at": deleted_at})
            .eq("user_id", user_id)
            .execute()
        )

        logger.info("user_data_deleted", user_id=user_id)


# Export singleton-style access
db = DatabaseService
