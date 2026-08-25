"""
Centralized, reusable LLM cost-tracking.

Every OpenRouter call in app/services/openrouter.py routes its usage/cost through
track_llm_usage() here. It never blocks the calling request: the DB insert is scheduled on
its own asyncio task (its own DB session, independent of the caller's request-scoped one) and
any failure is logged and swallowed rather than propagated, so a broken or slow usage-log write
can never delay a response or break an LLM call.
"""
import asyncio
import uuid
from decimal import Decimal, InvalidOperation

import structlog

from app.database import AsyncSessionLocal
from app.models.llm_usage import LlmUsageLog

logger = structlog.get_logger()

# Keep references to in-flight background tasks so they aren't garbage-collected mid-run.
_pending_tasks: set = set()


def track_llm_usage(
    *,
    feature: str,
    model: str,
    prompt_tokens: int = 0,
    completion_tokens: int = 0,
    total_tokens: int | None = None,
    cost_usd: float | Decimal | None = None,
    user_id: uuid.UUID | None = None,
    family_member_id: uuid.UUID | None = None,
    status: str = "success",
    error_message: str | None = None,
    duration_ms: float | None = None,
    request_id: str | None = None,
    provider: str = "openrouter",
) -> None:
    """
    Fire-and-forget entry point - call this right after (or instead of, on failure) an
    OpenRouter request completes. Schedules the actual DB write asynchronously and returns
    immediately without awaiting it.
    """
    task = asyncio.create_task(
        _persist_usage(
            feature=feature,
            model=model,
            prompt_tokens=prompt_tokens,
            completion_tokens=completion_tokens,
            total_tokens=total_tokens if total_tokens is not None else prompt_tokens + completion_tokens,
            cost_usd=cost_usd,
            user_id=user_id,
            family_member_id=family_member_id,
            status=status,
            error_message=error_message,
            duration_ms=round(duration_ms) if duration_ms is not None else None,
            request_id=request_id,
            provider=provider,
        )
    )
    _pending_tasks.add(task)
    task.add_done_callback(_pending_tasks.discard)


async def _persist_usage(
    *,
    feature: str,
    model: str,
    prompt_tokens: int,
    completion_tokens: int,
    total_tokens: int,
    cost_usd: float | Decimal | None,
    user_id: uuid.UUID | None,
    family_member_id: uuid.UUID | None,
    status: str,
    error_message: str | None,
    duration_ms: int | None,
    request_id: str | None,
    provider: str,
) -> None:
    try:
        normalized_cost = None
        if cost_usd is not None:
            try:
                normalized_cost = Decimal(str(cost_usd))
            except InvalidOperation:
                normalized_cost = None

        async with AsyncSessionLocal() as db:
            db.add(LlmUsageLog(
                user_id=user_id,
                family_member_id=family_member_id,
                feature=feature,
                provider=provider,
                model=model,
                prompt_tokens=prompt_tokens,
                completion_tokens=completion_tokens,
                total_tokens=total_tokens,
                cost_usd=normalized_cost,
                status=status,
                error_message=error_message[:2000] if error_message else None,
                duration_ms=duration_ms,
                request_id=request_id,
            ))
            await db.commit()
    except Exception as exc:
        # Never let a usage-logging failure surface anywhere near the LLM call path.
        logger.warning("LLM usage tracking failed", feature=feature, model=model, error=str(exc))
