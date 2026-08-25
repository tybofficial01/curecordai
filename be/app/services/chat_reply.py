"""
Non-streaming AI chat reply generation for the WhatsApp agent (answer_health_question tool).
Uses the exact same context assembly and disclaimer rules as the webapp's streaming chat
endpoint (app.services.chat_context, shared with ai_chat.py) - just a non-streaming caller of
them, so an answer given over WhatsApp matches what the same account would get on the web/app.
"""
import uuid

from app.config import settings
from app.core.enums import Language
from app.models.ai import AiChatSession
from app.services.chat_context import assemble_chat_context, compute_disclaimer, persist_assistant_message
from app.services.openrouter import chat_completion
from sqlalchemy.ext.asyncio import AsyncSession


async def generate_chat_reply(
    db: AsyncSession,
    session: AiChatSession,
    user_content: str,
    source_record_ids: list[uuid.UUID] | None = None,
    language: Language = Language.EN,
) -> dict:
    """
    Runs one full chat turn (persist user message, assemble context, call the LLM, persist +
    return the assistant reply) against an existing session. Returns
    {"content": str, "citations": list[dict], "is_urdu_script": bool}.
    `source_record_ids`, when given, grounds the answer in exactly those records (e.g. "what
    does this show?" on a document just uploaded over WhatsApp) - same attached-record path the
    webapp chat uses, instead of relying on RAG similarity search to guess the document meant.
    `language` should be the patient's saved language preference (see ai_chat.py) - per
    CHAT_SYSTEM rule 4 it's the fallback/default (the primary signal is the patient's own current
    message), but callers should still look it up rather than leaving the default, since it's
    what's used whenever the message itself gives no language signal.
    """
    ctx = await assemble_chat_context(db, session, user_content, source_record_ids=source_record_ids, language=language)

    result = await chat_completion(
        messages=ctx.messages,
        model=settings.AI_CHAT_MODEL,
        max_tokens=settings.AI_MAX_TOKENS_CHAT,
        feature="chat_whatsapp",
        user_id=session.user_id,
        family_member_id=session.family_member_id,
    )
    content = result["content"]

    effective_language, active_disclaimer = compute_disclaimer(content, language)
    if active_disclaimer not in content:
        content = f"{content}\n\n{active_disclaimer}"

    await persist_assistant_message(db, session, content, effective_language, active_disclaimer, ctx.grounding_record_ids)

    return {
        "content": content,
        "citations": [
            {"record_id": str(c.record_id), "title": c.title, "record_date": str(c.record_date) if c.record_date else None}
            for c in ctx.citations
        ],
        "is_urdu_script": effective_language == Language.UR,
    }
