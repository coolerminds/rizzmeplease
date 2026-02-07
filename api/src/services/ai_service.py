"""
RizzMePlease API - AI Service (OpenAI/xAI Integration)
"""

import json
import structlog
from datetime import datetime
from typing import Optional
from uuid import uuid4

from openai import AsyncOpenAI

from src.config import get_settings
from src.models import (
    ConversationData,
    Goal,
    Insight,
    InsightPriority,
    InsightType,
    Suggestion,
    Tone,
)

logger = structlog.get_logger()


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
        self.prompt_version = "v1.0"

    async def generate_suggestions(
        self,
        conversation: ConversationData,
        goal: Goal,
        tone: Tone,
        context: Optional[str] = None,
    ) -> list[Suggestion]:
        """Generate 3 reply suggestions based on goal and tone."""

        system_prompt = self._build_system_prompt(goal, tone)
        user_prompt = self._build_user_prompt(conversation, goal, context)

        logger.info(
            "ai_request_started",
            model=self.model,
            goal=goal.value,
            tone=tone.value,
            prompt_version=self.prompt_version,
        )

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
                raise ValueError("Empty response from AI")

            suggestions_data = json.loads(content)

            logger.info(
                "ai_request_completed",
                model=self.model,
                input_tokens=response.usage.prompt_tokens if response.usage else 0,
                output_tokens=response.usage.completion_tokens if response.usage else 0,
            )

            return self._parse_suggestions(suggestions_data)

        except Exception as e:
            logger.error("ai_request_failed", error=str(e))
            raise

    async def analyze_conversation(
        self,
        conversation: ConversationData,
        context: Optional[str] = None,
    ) -> tuple[list[Insight], int]:
        """Analyze conversation and return coach insights."""

        system_prompt = self._build_coach_system_prompt()
        user_prompt = self._build_coach_user_prompt(conversation, context)

        logger.info(
            "coach_analysis_started",
            model=self.model,
            message_count=len(conversation.messages),
        )

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
                raise ValueError("Empty response from AI")

            analysis_data = json.loads(content)

            logger.info(
                "coach_analysis_completed",
                input_tokens=response.usage.prompt_tokens if response.usage else 0,
                output_tokens=response.usage.completion_tokens if response.usage else 0,
            )

            return self._parse_insights(analysis_data)

        except Exception as e:
            logger.error("coach_analysis_failed", error=str(e))
            raise

    def _build_system_prompt(self, goal: Goal, tone: Tone) -> str:
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

OUTPUT FORMAT:
Respond with valid JSON matching this exact schema:
{{
  "suggestions": [
    {{
      "text": "The suggested message text (10-200 characters)",
      "rationale": "Brief explanation of why this approach works (20-150 characters)"
    }},
    // ... 3 suggestions total
  ]
}}

Generate exactly 3 unique suggestions, ranked from most to least recommended."""

    def _build_user_prompt(
        self,
        conversation: ConversationData,
        goal: Goal,
        context: Optional[str] = None,
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

    def _parse_suggestions(self, data: dict) -> list[Suggestion]:
        """Parse AI response into Suggestion models."""

        suggestions = []
        for i, item in enumerate(data.get("suggestions", [])[:3]):
            suggestions.append(
                Suggestion(
                    id=f"sug_{uuid4().hex[:8]}",
                    rank=i + 1,
                    text=item.get("text", ""),
                    rationale=item.get("rationale", ""),
                    confidence_score=round(0.9 - (i * 0.05), 2),  # 0.90, 0.85, 0.80
                )
            )
        return suggestions

    def _parse_insights(self, data: dict) -> tuple[list[Insight], int]:
        """Parse AI response into Insight models and score."""

        insights = []
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


# Singleton instance
ai_service = AIService()
