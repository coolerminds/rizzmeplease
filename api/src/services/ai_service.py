"""
RizzMePlease API - AI Service (OpenAI/xAI Integration)
"""

import json
import time
from datetime import datetime
from typing import Optional
from uuid import uuid4

import structlog
from openai import (
    APIConnectionError,
    APIStatusError,
    APITimeoutError,
    AsyncOpenAI,
    AuthenticationError,
    RateLimitError,
)

from src.config import get_settings
from src.models import (
    ConversationData,
    Goal,
    Insight,
    InsightPriority,
    InsightType,
    RelationshipType,
    Suggestion,
    Tone,
)

logger = structlog.get_logger()


class AIServiceError(Exception):
    """Structured AI service error for stable route-level handling."""

    def __init__(
        self,
        code: str,
        message: str,
        *,
        status_code: int = 502,
        retryable: bool = False,
        provider_status: Optional[int] = None,
    ) -> None:
        super().__init__(message)
        self.code = code
        self.message = message
        self.status_code = status_code
        self.retryable = retryable
        self.provider_status = provider_status


class AIService:
    """Handles all AI-powered suggestion and analysis generation."""

    def __init__(self) -> None:
        settings = get_settings()
        self.client = AsyncOpenAI(
            api_key=settings.ai_api_key,
            base_url=settings.ai_base_url,
            timeout=settings.openai_timeout,
        )
        self.model = settings.openai_model
        self.prompt_version = "v1.1"

    async def generate_suggestions(
        self,
        conversation: ConversationData,
        goal: Goal,
        tone: Tone,
        context: Optional[str] = None,
        relationship_type: Optional[RelationshipType] = None,
        thread_context: Optional[ConversationData] = None,
        request_id: Optional[str] = None,
    ) -> list[Suggestion]:
        """Generate 3 reply suggestions based on goal and tone."""

        system_prompt = self._build_system_prompt(goal, tone, relationship_type)
        user_prompt = self._build_user_prompt(
            conversation=conversation,
            goal=goal,
            context=context,
            thread_context=thread_context,
        )

        logger.info(
            "ai_request_started",
            request_id=request_id,
            model=self.model,
            goal=goal.value,
            tone=tone.value,
            relationship_type=relationship_type.value if relationship_type else None,
            thread_message_count=len(thread_context.messages) if thread_context else 0,
            prompt_version=self.prompt_version,
        )

        started = time.perf_counter()
        try:
            response = await self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt},
                ],
                response_format={"type": "json_object"},
                temperature=0.8,
                max_tokens=1000,
            )

            content = response.choices[0].message.content
            if not content:
                raise AIServiceError(
                    "AI_PARSE_ERROR",
                    "AI returned an empty response.",
                    status_code=502,
                    retryable=False,
                )

            suggestions_data = self._extract_json_object(content)
            suggestions = self._parse_suggestions(suggestions_data)
            if not suggestions:
                raise AIServiceError(
                    "AI_PARSE_ERROR",
                    "AI response did not contain valid suggestions.",
                    status_code=502,
                    retryable=False,
                )

            elapsed_ms = int((time.perf_counter() - started) * 1000)
            logger.info(
                "ai_request_completed",
                request_id=request_id,
                model=self.model,
                latency_ms=elapsed_ms,
                input_tokens=response.usage.prompt_tokens if response.usage else 0,
                output_tokens=response.usage.completion_tokens if response.usage else 0,
            )

            return suggestions

        except AIServiceError:
            raise
        except Exception as exc:
            mapped = self._map_provider_exception(exc)
            logger.error(
                "ai_request_failed",
                request_id=request_id,
                code=mapped.code,
                status_code=mapped.status_code,
                provider_status=mapped.provider_status,
                retryable=mapped.retryable,
                error=str(exc),
            )
            raise mapped

    async def analyze_conversation(
        self,
        conversation: ConversationData,
        context: Optional[str] = None,
        request_id: Optional[str] = None,
    ) -> tuple[list[Insight], int]:
        """Analyze conversation and return coach insights."""

        system_prompt = self._build_coach_system_prompt()
        user_prompt = self._build_coach_user_prompt(conversation, context)

        logger.info(
            "coach_analysis_started",
            request_id=request_id,
            model=self.model,
            message_count=len(conversation.messages),
        )

        started = time.perf_counter()
        try:
            response = await self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt},
                ],
                response_format={"type": "json_object"},
                temperature=0.6,
                max_tokens=1000,
            )

            content = response.choices[0].message.content
            if not content:
                raise AIServiceError(
                    "AI_PARSE_ERROR",
                    "AI returned an empty response.",
                    status_code=502,
                    retryable=False,
                )

            analysis_data = self._extract_json_object(content)

            elapsed_ms = int((time.perf_counter() - started) * 1000)
            logger.info(
                "coach_analysis_completed",
                request_id=request_id,
                latency_ms=elapsed_ms,
                input_tokens=response.usage.prompt_tokens if response.usage else 0,
                output_tokens=response.usage.completion_tokens if response.usage else 0,
            )

            return self._parse_insights(analysis_data)

        except AIServiceError:
            raise
        except Exception as exc:
            mapped = self._map_provider_exception(exc)
            logger.error(
                "coach_analysis_failed",
                request_id=request_id,
                code=mapped.code,
                status_code=mapped.status_code,
                provider_status=mapped.provider_status,
                retryable=mapped.retryable,
                error=str(exc),
            )
            raise mapped

    def _build_system_prompt(
        self,
        goal: Goal,
        tone: Tone,
        relationship_type: Optional[RelationshipType] = None,
    ) -> str:
        """Build system prompt for suggestion generation."""

        goal_instructions = {
            Goal.GET_REPLY: "Focus on crafting messages that invite a response. Use open-ended questions, show genuine interest, and create conversational hooks.",
            Goal.ASK_MEETUP: "Focus on transitioning from texting to an in-person meeting. Be specific about time/place suggestions, keep it low-pressure but clear.",
            Goal.SET_BOUNDARY: "Focus on communicating limits clearly and respectfully. Be firm but kind, avoid over-explaining or apologizing excessively.",
        }

        tone_instructions = {
            Tone.FRIENDLY: "Use a light, approachable style. Incorporate casual language, occasional humor, and enthusiasm.",
            Tone.DIRECT: "Be clear and concise. Get to the point without fluff. Use straightforward language.",
            Tone.WARM: "Be empathetic and caring. Show emotional awareness. Use gentle, supportive language.",
            Tone.CONFIDENT: "Be self-assured without being arrogant. Project security and groundedness. Avoid needy language.",
        }

        relationship_instructions = {
            RelationshipType.FRIEND: "Treat this as a peer relationship. Keep language natural, respectful, and not overly formal.",
            RelationshipType.STRANGER: "Prioritize safety, clarity, and politeness. Avoid overfamiliar tone and avoid pressure.",
            RelationshipType.PROFESSIONAL: "Use professional, concise language. Respect boundaries and avoid flirtatious suggestions.",
            RelationshipType.DATING: "Allow playful warmth when appropriate, but avoid manipulative, pushy, or objectifying language.",
        }

        relationship_label = (
            relationship_type.value.replace("_", " ").title()
            if relationship_type
            else "Not specified"
        )
        relationship_guidance = relationship_instructions.get(
            relationship_type,
            "Use neutral, respectful language and infer context conservatively.",
        )

        return f"""You are an expert texting coach helping users communicate more effectively in dating and social contexts.

ROLE: Provide authentic, respectful message suggestions that help users achieve their communication goals.

RULES:
- Never suggest manipulative, deceptive, or harmful messages
- Respect the other person's autonomy and boundaries
- Encourage genuine connection over "tricks"
- Keep suggestions natural and conversational
- Match the user's voice (don't be overly formal)

GOAL: {goal.value.replace("_", " ").title()}
{goal_instructions[goal]}

TONE: {tone.value.title()}
{tone_instructions[tone]}

RELATIONSHIP TYPE: {relationship_label}
{relationship_guidance}

OUTPUT FORMAT:
Respond with valid JSON matching this exact schema:
{{
  "suggestions": [
    {{
      "text": "The suggested message text (10-200 characters)",
      "rationale": "Brief explanation of why this approach works (20-150 characters)"
    }}
    // ... 3 suggestions total
  ]
}}

Generate exactly 3 unique suggestions, ranked from most to least recommended."""

    def _build_user_prompt(
        self,
        conversation: ConversationData,
        goal: Goal,
        context: Optional[str] = None,
        thread_context: Optional[ConversationData] = None,
    ) -> str:
        """Build user prompt with conversation and context."""

        formatted_messages = "\n".join(
            f"{'You' if msg.sender.lower() == 'you' else 'Them'}: {msg.text}"
            for msg in conversation.messages
        )

        prompt = f"""Here is the conversation so far:

{formatted_messages}

Generate 3 reply suggestions for the user's next message.
Goal: {goal.value.replace("_", " ").title()}"""

        if thread_context and thread_context.messages:
            thread_messages = "\n".join(
                f"{'You' if msg.sender.lower() == 'you' else 'Them'}: {msg.text}"
                for msg in thread_context.messages
            )
            prompt += f"\n\nThread context from iMessage extension:\n{thread_messages}"

        if context:
            prompt += f"\n\nAdditional context: {context}"

        return prompt

    def _build_coach_system_prompt(self) -> str:
        """Build system prompt for coach analysis."""

        return """You are an expert communication coach analyzing text message conversations.

Your job is to identify patterns, opportunities, and actionable insights to help the user improve their texting skills.

Focus on:
- Response time patterns
- Question/statement balance
- Energy matching
- Conversation momentum
- Escalation opportunities

OUTPUT FORMAT:
Respond with valid JSON matching this exact schema:
{
  "insights": [
    {
      "type": "pattern" | "opportunity" | "strength",
      "title": "Short title (max 50 chars)",
      "description": "Actionable insight (max 200 chars)",
      "priority": "high" | "medium" | "low"
    }
    // 2-4 insights
  ],
  "overall_score": 0-100 (communication effectiveness score)
}"""

    def _build_coach_user_prompt(
        self,
        conversation: ConversationData,
        context: Optional[str] = None,
    ) -> str:
        """Build user prompt for coach analysis."""

        formatted_messages = "\n".join(
            f"{'You' if msg.sender.lower() == 'you' else 'Them'}: {msg.text}"
            for msg in conversation.messages
        )

        prompt = f"""Analyze this conversation:

{formatted_messages}

Provide 2-4 actionable insights and an overall score."""

        if context:
            prompt += f"\n\nContext: {context}"

        return prompt

    def _extract_json_object(self, content: str) -> dict:
        """Extract a JSON object from an LLM response robustly."""

        stripped = content.strip()
        try:
            payload = json.loads(stripped)
            if isinstance(payload, dict):
                return payload
        except json.JSONDecodeError:
            pass

        # Fallback: recover first JSON object in mixed text responses.
        start = stripped.find("{")
        end = stripped.rfind("}")
        if start == -1 or end == -1 or start >= end:
            raise AIServiceError(
                "AI_PARSE_ERROR",
                "AI response was not valid JSON.",
                status_code=502,
                retryable=False,
            )

        try:
            payload = json.loads(stripped[start : end + 1])
        except json.JSONDecodeError as exc:
            raise AIServiceError(
                "AI_PARSE_ERROR",
                "AI response JSON could not be parsed.",
                status_code=502,
                retryable=False,
            ) from exc

        if not isinstance(payload, dict):
            raise AIServiceError(
                "AI_PARSE_ERROR",
                "AI response JSON did not contain an object.",
                status_code=502,
                retryable=False,
            )
        return payload

    def _parse_suggestions(self, data: dict) -> list[Suggestion]:
        """Parse AI response into Suggestion models."""

        raw_items = data.get("suggestions")
        if not isinstance(raw_items, list):
            raw_items = []

        suggestions: list[Suggestion] = []
        seen: set[str] = set()

        for item in raw_items[:3]:
            if not isinstance(item, dict):
                continue
            text = str(item.get("text", "")).strip()
            rationale = str(item.get("rationale", "")).strip()
            if not text:
                continue

            key = text.lower()
            if key in seen:
                continue
            seen.add(key)

            suggestions.append(
                Suggestion(
                    id=f"sug_{uuid4().hex[:8]}",
                    rank=len(suggestions) + 1,
                    text=text[:200],
                    rationale=(
                        rationale[:150]
                        if rationale
                        else "Suggested from conversation context and communication goal."
                    ),
                    confidence_score=round(0.9 - (len(suggestions) * 0.05), 2),
                )
            )

        if len(suggestions) < 3:
            for text, rationale in self._fallback_suggestion_templates():
                if len(suggestions) >= 3:
                    break
                key = text.lower()
                if key in seen:
                    continue
                seen.add(key)
                suggestions.append(
                    Suggestion(
                        id=f"sug_{uuid4().hex[:8]}",
                        rank=len(suggestions) + 1,
                        text=text,
                        rationale=rationale,
                        confidence_score=round(0.9 - (len(suggestions) * 0.05), 2),
                    )
                )

        return suggestions

    def _parse_insights(self, data: dict) -> tuple[list[Insight], int]:
        """Parse AI response into Insight models and score."""

        insights: list[Insight] = []
        for item in data.get("insights", [])[:4]:
            try:
                insights.append(
                    Insight(
                        type=InsightType(item.get("type", "pattern")),
                        title=item.get("title", ""),
                        description=item.get("description", ""),
                        priority=InsightPriority(item.get("priority", "medium")),
                    )
                )
            except ValueError:
                continue

        overall_score = min(100, max(0, int(data.get("overall_score", 70))))
        return insights, overall_score

    @staticmethod
    def _fallback_suggestion_templates() -> list[tuple[str, str]]:
        """Stable local templates used only when model output is malformed."""

        return [
            (
                "That sounds good. Want to share a little more?",
                "Keeps momentum by inviting a concrete follow-up.",
            ),
            (
                "I like where this is going. What feels best for you next?",
                "Signals interest while giving the other person space to respond.",
            ),
            (
                "Thanks for sharing that. I am open to continuing this.",
                "Comes across clear and respectful without overcommitting.",
            ),
        ]

    @staticmethod
    def _map_provider_exception(exc: Exception) -> AIServiceError:
        """Translate provider SDK errors into stable API-facing error types."""

        if isinstance(exc, APITimeoutError):
            return AIServiceError(
                "AI_TIMEOUT",
                "AI provider timed out while generating suggestions.",
                status_code=504,
                retryable=True,
            )

        if isinstance(exc, APIConnectionError):
            return AIServiceError(
                "AI_TRANSPORT_ERROR",
                "Unable to reach AI provider.",
                status_code=502,
                retryable=True,
            )

        if isinstance(exc, RateLimitError):
            return AIServiceError(
                "AI_RATE_LIMIT",
                "AI provider rate limit reached. Please retry shortly.",
                status_code=429,
                retryable=False,
                provider_status=429,
            )

        if isinstance(exc, AuthenticationError):
            return AIServiceError(
                "AI_AUTH_ERROR",
                "AI provider authentication failed.",
                status_code=502,
                retryable=False,
                provider_status=401,
            )

        if isinstance(exc, APIStatusError):
            provider_status = exc.status_code or 500
            if provider_status == 401:
                return AIServiceError(
                    "AI_AUTH_ERROR",
                    "AI provider authentication failed.",
                    status_code=502,
                    retryable=False,
                    provider_status=provider_status,
                )
            if provider_status == 402:
                return AIServiceError(
                    "AI_BILLING_ERROR",
                    "AI provider billing/credits required.",
                    status_code=502,
                    retryable=False,
                    provider_status=provider_status,
                )
            if provider_status == 429:
                return AIServiceError(
                    "AI_RATE_LIMIT",
                    "AI provider rate limit reached. Please retry shortly.",
                    status_code=429,
                    retryable=False,
                    provider_status=provider_status,
                )
            if provider_status >= 500:
                return AIServiceError(
                    "AI_UPSTREAM_ERROR",
                    "AI provider returned an upstream error.",
                    status_code=502,
                    retryable=True,
                    provider_status=provider_status,
                )

            return AIServiceError(
                "AI_REQUEST_ERROR",
                "AI provider rejected the request payload.",
                status_code=502,
                retryable=False,
                provider_status=provider_status,
            )

        return AIServiceError(
            "AI_ERROR",
            "Unexpected AI provider error.",
            status_code=502,
            retryable=False,
        )


# Singleton instance
ai_service = AIService()
