"""
AI chat API with SSE streaming.
Every assistant message MUST include a medical disclaimer per product requirement.

Context grounding (see docs/ai-chat-context.md for the full design):
  Phase 1 - structured snapshot of the patient's active clinical data (patient_context.py)
  Phase 2 - semantic retrieval over the patient's uploaded documents (record_retrieval.py)
  Phase 3 - rolling summary of aged-out conversation history (chat_memory.py)
A session is scoped to exactly one patient (the account owner, or one linked family member)
for its whole lifetime, set at creation and enforced on every query - never both.
"""
import json
import uuid
from datetime import date, datetime, timezone

import structlog
from fastapi import APIRouter, BackgroundTasks, Body, Query, Request, status
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field
from sqlalchemy import select

from app.config import settings
from app.core.enums import Language
from app.core.errors import ApiError, ErrorCode
from app.core.rate_limit import limiter
from app.core.scoping import family_scope, validate_family_member_ownership
from app.database import AsyncSessionLocal
from app.dependencies import CurrentUser, DB
from app.models.ai import AiChatMessage, AiChatSession
from app.models.settings import AppSetting
from app.services.chat_context import (
    Citation,
    assemble_chat_context,
    compute_disclaimer,
    persist_assistant_message,
    resolve_citations,
)
from app.services.openrouter import chat_completion, chat_completion_stream
from app.services.prompts import CHAT_TITLE_SYSTEM

logger = structlog.get_logger()

router = APIRouter(prefix="/ai", tags=["ai"])


class ChatSessionOut(BaseModel):
    id: uuid.UUID
    family_member_id: uuid.UUID | None
    title: str | None
    status: str
    total_messages: int
    is_pinned: bool
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class UpdateSessionRequest(BaseModel):
    title: str | None = Field(None, min_length=1, max_length=255)
    is_pinned: bool | None = None


class ChatCitation(BaseModel):
    """A record that grounded an assistant answer - rendered as a clickable source chip."""
    record_id: uuid.UUID
    title: str
    record_type: str
    record_date: date | None


class ChatMessageOut(BaseModel):
    id: uuid.UUID
    session_id: uuid.UUID
    role: str
    content: str
    disclaimer_included: bool
    model_version: str | None
    created_at: datetime
    citations: list[ChatCitation] = []


class CreateSessionRequest(BaseModel):
    family_member_id: uuid.UUID | None = None


class SendMessageRequest(BaseModel):
    content: str = Field(..., min_length=1, max_length=4000)
    source_record_ids: list[uuid.UUID] | None = None


@router.get("/sessions", response_model=list[ChatSessionOut])
async def list_sessions(
    current_user: CurrentUser,
    db: DB,
    family_member_id: uuid.UUID | None = None,
    limit: int = Query(20, le=100),
):
    query = select(AiChatSession).where(
        AiChatSession.user_id == current_user.id,
        AiChatSession.is_deleted == False,  # noqa: E712
        AiChatSession.total_messages > 0,
        family_scope(AiChatSession, family_member_id),
    )
    sessions = (await db.scalars(
        query.order_by(AiChatSession.is_pinned.desc(), AiChatSession.updated_at.desc()).limit(limit)
    )).all()
    return [ChatSessionOut.model_validate(s) for s in sessions]


@router.post("/sessions", response_model=ChatSessionOut, status_code=status.HTTP_201_CREATED)
async def create_session(current_user: CurrentUser, db: DB, body: CreateSessionRequest | None = Body(default=None)):
    """Creates a session scoped to one patient - the account owner (default) or a linked family member."""
    family_member_id = body.family_member_id if body else None
    await validate_family_member_ownership(db, current_user.id, family_member_id)
    session = AiChatSession(user_id=current_user.id, family_member_id=family_member_id, status="active")
    db.add(session)
    await db.commit()
    await db.refresh(session)
    return ChatSessionOut.model_validate(session)


@router.patch("/sessions/{session_id}", response_model=ChatSessionOut)
async def update_session(
    session_id: uuid.UUID, body: UpdateSessionRequest, current_user: CurrentUser, db: DB,
):
    """Rename and/or pin/unpin a chat session. Either field may be sent alone."""
    session = await _get_session_or_404(db, session_id, current_user.id)
    if body.title is not None:
        session.title = body.title.strip()[:255] or session.title
    if body.is_pinned is not None:
        session.is_pinned = body.is_pinned
    await db.commit()
    await db.refresh(session)
    return ChatSessionOut.model_validate(session)


@router.get("/sessions/{session_id}/messages", response_model=list[ChatMessageOut])
async def get_messages(
    session_id: uuid.UUID, current_user: CurrentUser, db: DB, limit: int = Query(50, le=200)
):
    session = await _get_session_or_404(db, session_id, current_user.id)
    messages = (await db.scalars(
        select(AiChatMessage)
        .where(AiChatMessage.session_id == session_id)
        .order_by(AiChatMessage.created_at.asc())
        .limit(limit)
    )).all()

    all_record_ids = {
        record_id
        for m in messages if m.grounding_record_ids
        for record_id in json.loads(m.grounding_record_ids)
    }
    citation_map = await resolve_citations(db, all_record_ids)

    return [
        ChatMessageOut(
            id=m.id,
            session_id=m.session_id,
            role=m.role,
            content=m.content,
            disclaimer_included=m.disclaimer_included,
            model_version=m.model_version,
            created_at=m.created_at,
            citations=_citations_for(m, citation_map),
        )
        for m in messages
    ]


@router.post("/sessions/{session_id}/messages/stream")
@limiter.limit("30/minute")
async def send_message_stream(
    session_id: uuid.UUID,
    body: SendMessageRequest,
    request: Request,
    current_user: CurrentUser,
    db: DB,
    background_tasks: BackgroundTasks,
):
    """
    Send a message and stream the AI response via Server-Sent Events.
    Client should read `data:` lines; `data: [DONE]` signals end of stream.
    """
    logger.debug(
        "AI chat message received",
        session_id=str(session_id),
        user_id=str(current_user.id),
        content_chars=len(body.content),
        source_record_count=len(body.source_record_ids or []),
    )
    session = await _get_session_or_404(db, session_id, current_user.id)
    family_member_id = session.family_member_id

    user_language = await db.scalar(
        select(AppSetting.language).where(AppSetting.user_id == current_user.id)
    )
    language = Language(user_language) if user_language else Language.EN

    # Shared with the WhatsApp agent's non-streaming reply (chat_reply.py) - same 3-layer
    # grounding (snapshot / RAG / history-summary), same attached-record handling, so this
    # endpoint and WhatsApp behave identically for the same account.
    ctx = await assemble_chat_context(
        db, session, body.content, source_record_ids=body.source_record_ids, language=language,
    )
    openrouter_messages = ctx.messages
    citations = ctx.citations
    grounding_record_ids = ctx.grounding_record_ids

    async def event_generator():
        full_response = []
        logger.debug(
            "AI chat stream starting",
            session_id=str(session_id),
            history_messages=len(openrouter_messages),
            citation_count=len(citations),
        )
        try:
            async for chunk in chat_completion_stream(
                messages=openrouter_messages,
                model=settings.AI_CHAT_MODEL,
                max_tokens=settings.AI_MAX_TOKENS_CHAT,
                feature="chat",
                user_id=current_user.id,
                family_member_id=family_member_id,
            ):
                full_response.append(chunk)
                yield f"data: {json.dumps({'chunk': chunk})}\n\n"

            complete_response = "".join(full_response)

            # The model replies (and closes) in whichever language its own current message
            # signals (CHAT_SYSTEM rule 4), which may differ from the saved preference - so
            # compute_disclaimer checks for any of the three disclaimer variants already present
            # before deciding what to append, rather than assuming the saved-preference one.
            effective_language, active_disclaimer = compute_disclaimer(complete_response, language)

            # Ensure disclaimer is present (safety net)
            if active_disclaimer not in complete_response:
                disclaimer_chunk = f"\n\n{active_disclaimer}"
                complete_response += disclaimer_chunk
                yield f"data: {json.dumps({'chunk': disclaimer_chunk})}\n\n"

            # Commit the actual chat turn now - auto-titling is a separate, best-effort LLM
            # call that must never block or risk this commit. It runs as a background task
            # after the response is sent (see below), on its own DB session.
            await persist_assistant_message(
                db, session, complete_response, effective_language, active_disclaimer, grounding_record_ids,
            )
            needs_title = session.total_messages <= 2 and not session.title
            logger.info(
                "AI chat response completed",
                session_id=str(session_id),
                user_id=str(current_user.id),
                response_chars=len(complete_response),
                grounding_record_count=len(grounding_record_ids),
            )

            # Sources used for this answer - rendered client-side as clickable citation chips
            if citations:
                yield f"data: {json.dumps({'citations': [_to_chat_citation(c).model_dump(mode='json') for c in citations]})}\n\n"

            if needs_title:
                background_tasks.add_task(_apply_auto_title, session_id, body.content)

        except Exception as exc:
            logger.error("AI chat stream failed", session_id=str(session_id), error=str(exc), exc_info=True)
            yield f"data: {json.dumps({'error': 'AI service unavailable'})}\n\n"

        yield "data: [DONE]\n\n"

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",
        },
        background=background_tasks,
    )


@router.delete("/sessions/{session_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_session(session_id: uuid.UUID, current_user: CurrentUser, db: DB):
    session = await _get_session_or_404(db, session_id, current_user.id)
    session.is_deleted = True
    session.deleted_at = datetime.now(timezone.utc)
    await db.commit()


async def _apply_auto_title(session_id: uuid.UUID, first_message: str) -> None:
    """
    Runs as a FastAPI background task, after the chat turn's SSE response has already been
    sent - on its own DB session, independent of the request's `db`. Auto-titling is
    best-effort and must never delay or risk the commit of the actual chat turn (which has
    already happened by the time this runs); a slow or failed title generation here only
    means the title shows up a little later on the next session-list refresh, never a lost
    or corrupted message.
    """
    try:
        async with AsyncSessionLocal() as db:
            session = await db.get(AiChatSession, session_id)
            if not session or session.title:
                return
            session.title = await _generate_session_title(
                first_message, session.user_id, session.family_member_id
            )
            await db.commit()
    except Exception as exc:
        logger.warning("Auto-title background task failed", session_id=str(session_id), error=str(exc))


async def _generate_session_title(
    first_message: str, user_id: uuid.UUID, family_member_id: uuid.UUID | None
) -> str:
    """
    Generates a concise chat-list title from the patient's first message via a small LLM call.
    `first_message` is untrusted patient input - CHAT_TITLE_SYSTEM instructs the model to treat
    it purely as content to summarize, never as instructions. Falls back to truncation if the
    LLM call fails or returns something unusable, so a slow/broken title service never blocks
    the chat response that already streamed successfully.
    """
    try:
        result = await chat_completion(
            messages=[
                {"role": "system", "content": CHAT_TITLE_SYSTEM},
                {"role": "user", "content": first_message[:2000]},
            ],
            model=settings.AI_CHAT_MODEL,
            max_tokens=20,
            temperature=0.3,
            feature="chat_title",
            user_id=user_id,
            family_member_id=family_member_id,
        )
        title = (result.get("content") or "").strip().strip('"').strip()
        if title and not title.startswith("[AI unavailable"):
            return title[:80]
    except Exception as exc:
        logger.warning("Auto-title generation failed, falling back to truncation", error=str(exc))
    return first_message[:80]


async def _get_session_or_404(db, session_id: uuid.UUID, user_id: uuid.UUID) -> AiChatSession:
    session = await db.scalar(
        select(AiChatSession).where(
            AiChatSession.id == session_id,
            AiChatSession.user_id == user_id,
            AiChatSession.is_deleted == False,  # noqa: E712
        )
    )
    if not session:
        logger.debug("Chat session not found", session_id=str(session_id), user_id=str(user_id))
        raise ApiError(status_code=status.HTTP_404_NOT_FOUND, detail="Chat session not found", error_code=ErrorCode.CHAT_SESSION_NOT_FOUND)
    return session


def _to_chat_citation(c: Citation) -> ChatCitation:
    return ChatCitation(record_id=c.record_id, title=c.title, record_type=c.record_type, record_date=c.record_date)


def _citations_for(message: AiChatMessage, citation_map: dict[str, Citation]) -> list[ChatCitation]:
    """Most recent record first - a sensible default ordering for a flat chip list."""
    if not message.grounding_record_ids:
        return []
    ids = json.loads(message.grounding_record_ids)
    citations = [citation_map[i] for i in ids if i in citation_map]
    return [_to_chat_citation(c) for c in sorted(citations, key=lambda c: c.record_date or date.min, reverse=True)]
