"""
Fixed-batch history compaction for AI chat sessions (Phase 3). The conversation is split into
non-overlapping, gapless ranges by a single pointer, session.history_summarized_count (K):
  - messages[:K]  → already folded into independent per-batch AiChatHistorySummary rows
  - messages[K:]  → sent raw, verbatim
Each batch of KEEP_RECENT messages gets its own summary, stored once and never rewritten or
merged with other batches - batch 1 always covers messages 1-20, batch 2 always 21-40, etc.
At prompt-build time all stored batches are read back in order and sent alongside the raw tail.
"""
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models.ai import AiChatHistorySummary, AiChatMessage, AiChatSession
from app.services.openrouter import chat_completion
from app.services.prompts import HISTORY_SUMMARY_SYSTEM, HISTORY_SUMMARY_USER

KEEP_RECENT = 20   # batch size - once the raw tail (messages after K) reaches this, it becomes a batch


async def maybe_compact_history(db: AsyncSession, session: AiChatSession) -> None:
    """
    Turns the oldest unsummarized block of KEEP_RECENT messages into its own AiChatHistorySummary
    row whenever the raw tail reaches that size - i.e. every 20 messages, in fixed, independent
    batches. Loops so it self-heals if more than one batch's worth ever backs up. Mutates
    `session` in place; caller's existing commit persists both the new row and the pointer.
    """
    while session.total_messages - session.history_summarized_count >= KEEP_RECENT:
        batch = (await db.scalars(
            select(AiChatMessage)
            .where(AiChatMessage.session_id == session.id)
            .order_by(AiChatMessage.created_at.asc())
            .offset(session.history_summarized_count)
            .limit(KEEP_RECENT)
        )).all()
        if not batch:
            return

        turns_text = "\n".join(f"{m.role}: {m.content}" for m in batch)
        result = await chat_completion(
            messages=[
                {"role": "system", "content": HISTORY_SUMMARY_SYSTEM},
                {"role": "user", "content": HISTORY_SUMMARY_USER.format(new_turns=turns_text)},
            ],
            model=settings.AI_CHAT_MODEL,
            max_tokens=settings.AI_MAX_TOKENS_HISTORY_SUMMARY,
            temperature=0.1,
            feature="chat_history_summary",
            user_id=session.user_id,
            family_member_id=session.family_member_id,
        )

        batch_index = session.history_summarized_count // KEEP_RECENT + 1
        db.add(AiChatHistorySummary(
            session_id=session.id,
            batch_index=batch_index,
            summary_text=result["content"],
        ))
        session.history_summarized_count += len(batch)


async def get_batch_summaries_text(db: AsyncSession, session: AiChatSession) -> str | None:
    """Returns all stored batch summaries for the session, oldest first, formatted for prompt injection."""
    batches = (await db.scalars(
        select(AiChatHistorySummary)
        .where(AiChatHistorySummary.session_id == session.id)
        .order_by(AiChatHistorySummary.batch_index.asc())
    )).all()
    if not batches:
        return None
    return "\n\n".join(f"[Batch {b.batch_index}]\n{b.summary_text}" for b in batches)
