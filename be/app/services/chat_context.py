"""
Shared chat-turn context assembly, used identically by the webapp's streaming AI chat endpoint
(ai_chat.py) and the WhatsApp agent's non-streaming reply (chat_reply.py) - one implementation
of the 3-layer grounding (snapshot / RAG / history-summary) and disclaimer rules, so a question
answered through either channel behaves the same way for the same account instead of two
independent copies that can quietly drift apart.
"""
import json
import uuid
import asyncio
from dataclasses import dataclass
from datetime import date

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.core.enums import Language
from app.core.scoping import family_scope
from app.database import AsyncSessionLocal
from app.models.ai import AiChatMessage, AiChatSession
from app.models.clinical import AllergyIntolerance, Condition, Encounter, MedicationRequest, Observation
from app.models.records import MedicalRecord
from app.services.chat_memory import get_batch_summaries_text, maybe_compact_history
from app.services.patient_context import build_snapshot
from app.services.prompts import (
    AI_DISCLAIMERS,
    CHAT_HISTORY_SUMMARY_HEADER,
    CHAT_RAG_HEADER,
    CHAT_SNAPSHOT_HEADER,
    CHAT_SYSTEM,
    ai_disclaimer,
    chat_language_system,
)
from app.services.record_retrieval import format_chunks_for_prompt, retrieve_relevant_chunks


@dataclass
class Citation:
    record_id: uuid.UUID
    title: str
    record_type: str
    record_date: date | None


@dataclass
class ChatTurnContext:
    messages: list[dict]
    citations: list[Citation]
    grounding_record_ids: set[uuid.UUID]


async def assemble_chat_context(
    db: AsyncSession,
    session: AiChatSession,
    user_content: str,
    source_record_ids: list[uuid.UUID] | None = None,
    language: Language = Language.EN,
) -> ChatTurnContext:
    """
    Persists the user message, then assembles one chat turn's context: RAG retrieval (or, if
    source_record_ids is given, everything stored about those exact records) + patient snapshot
    + rolling history summary + raw recent history, in the same 4-layer system-prompt structure
    for every caller. `language` carries the patient's saved language preference (defaults to
    English for callers, like the WhatsApp agent, that don't look one up).
    """
    user_id = session.user_id
    family_member_id = session.family_member_id
    session_id = session.id

    user_msg = AiChatMessage(
        session_id=session_id,
        user_id=user_id,
        role="user",
        content=user_content,
        source_record_ids=json.dumps([str(r) for r in source_record_ids]) if source_record_ids else None,
        disclaimer_included=False,
    )
    db.add(user_msg)
    session.total_messages += 1
    await db.commit()

    await maybe_compact_history(db, session)

    async def _run_phase2():
        async with AsyncSessionLocal() as s:
            if source_record_ids:
                text, record_ids = await _build_attached_records_context(
                    s, user_id, family_member_id, source_record_ids,
                )
                return [], text, record_ids
            chunks = await retrieve_relevant_chunks(s, user_id, family_member_id, user_content)
            return chunks, None, set()

    async def _run_snapshot_and_summaries():
        snapshot_result = await build_snapshot(db, user_id, family_member_id)
        summaries_result = await get_batch_summaries_text(db, session)
        return snapshot_result, summaries_result

    (
        (chunks, attached_context_text, attached_record_ids),
        ((snapshot_text, snapshot_record_ids), batch_summaries_text),
    ) = await asyncio.gather(_run_phase2(), _run_snapshot_and_summaries())

    grounding_record_ids = set(snapshot_record_ids) | {c["record_id"] for c in chunks} | attached_record_ids
    citation_map = await resolve_citations(db, {str(r) for r in grounding_record_ids})
    citations = sorted(citation_map.values(), key=lambda c: c.record_date or date.min, reverse=True)

    history = await fetch_recent_history(db, session)

    messages = [
        {"role": "system", "content": CHAT_SYSTEM},
        {"role": "system", "content": chat_language_system(language)},
    ]
    if batch_summaries_text:
        messages.append({"role": "system", "content": f"{CHAT_HISTORY_SUMMARY_HEADER}\n{batch_summaries_text}"})
    if snapshot_text:
        messages.append({"role": "system", "content": f"{CHAT_SNAPSHOT_HEADER}\n{snapshot_text}"})
    if chunks:
        messages.append({"role": "system", "content": f"{CHAT_RAG_HEADER}\n{format_chunks_for_prompt(chunks)}"})
    if attached_context_text:
        messages.append({"role": "system", "content": attached_context_text})
    messages.extend(history)

    return ChatTurnContext(messages=messages, citations=citations, grounding_record_ids=grounding_record_ids)


async def fetch_recent_history(db: AsyncSession, session: AiChatSession) -> list[dict]:
    """
    Raw history = everything after the summary pointer (session.history_summarized_count) -
    never independently "last N by recency", which would drift out of sync with the rolling
    summary and leave a gap. maybe_compact_history() guarantees this is at most KEEP_RECENT rows.
    Shared by chat turn assembly and the WhatsApp router (which needs conversation context to
    resolve a follow-up like "send me that one" or "what about her cholesterol").
    """
    rows = (await db.execute(
        select(AiChatMessage.role, AiChatMessage.content)
        .where(AiChatMessage.session_id == session.id)
        .order_by(AiChatMessage.created_at.asc())
        .offset(session.history_summarized_count)
    )).all()
    return [{"role": r.role, "content": r.content} for r in rows]


async def persist_turn(db: AsyncSession, session: AiChatSession, user_content: str, assistant_content: str) -> None:
    """
    Persists a plain user+assistant turn with no RAG/snapshot grounding and no disclaimer -
    for WhatsApp tool turns (document search/list/send, small talk) that don't go through
    generate_chat_reply's full pipeline but still need to exist in session history so later
    turns (and the router) have continuity. Mirrors assemble_chat_context's compaction step.
    """
    db.add(AiChatMessage(session_id=session.id, user_id=session.user_id, role="user", content=user_content, disclaimer_included=False))
    db.add(AiChatMessage(session_id=session.id, user_id=session.user_id, role="assistant", content=assistant_content, disclaimer_included=False))
    session.total_messages += 2
    await db.commit()
    await maybe_compact_history(db, session)


def compute_disclaimer(content: str, language: Language = Language.EN) -> tuple[Language, str]:
    """
    The model replies (and is now instructed to close) in whichever of the three disclaimer
    variants matches the language/script it actually used (see chat_language_system) - which,
    per CHAT_SYSTEM rule 4, may differ from the patient's saved preference whenever their current
    message has its own clear language. So first check whether the model already appended one of
    the three known disclaimer texts and, if so, trust that language - only when none is present
    yet does this fall back to script detection (Urdu script -> Urdu) and finally to the passed
    `language` (the saved preference) as the last resort default, to decide what to append.
    """
    for lang, text in AI_DISCLAIMERS.items():
        if text in content:
            return lang, text
    is_urdu_script = any("؀" <= ch <= "ۿ" for ch in content)
    effective_language = Language.UR if is_urdu_script else language
    return effective_language, ai_disclaimer(effective_language)


async def persist_assistant_message(
    db: AsyncSession,
    session: AiChatSession,
    content: str,
    language: Language,
    active_disclaimer: str,
    grounding_record_ids: set[uuid.UUID],
) -> AiChatMessage:
    """Persists the assistant turn. `content` must already include the disclaimer if needed -
    callers decide whether/how to surface the appended disclaimer text (e.g. as an extra
    streamed chunk) before calling this."""
    assistant_msg = AiChatMessage(
        session_id=session.id,
        user_id=session.user_id,
        role="assistant",
        content=content,
        disclaimer_included=True,
        disclaimer_text=active_disclaimer,
        disclaimer_language=language.value,
        model_version=settings.AI_CHAT_MODEL,
        grounding_record_ids=json.dumps([str(r) for r in grounding_record_ids]),
    )
    db.add(assistant_msg)
    session.total_messages += 1
    await db.commit()
    return assistant_msg


async def _build_attached_records_context(
    db: AsyncSession,
    user_id: uuid.UUID,
    family_member_id: uuid.UUID | None,
    source_record_ids: list[uuid.UUID],
) -> tuple[str | None, set[uuid.UUID]]:
    """
    Whenever the patient explicitly tags/attaches a document, feed the model everything stored
    about it directly - title, stored AI summary, and every clinical entity (conditions,
    medications, labs, allergies, encounters) extracted from it - rather than relying on
    embedding similarity search to guess which fragments are relevant. Scoped to the requesting
    patient exactly like every other query here - a source_record_id for someone else's record
    must never leak its data back to this user.
    """
    if not source_record_ids:
        return None, set()

    records = (await db.scalars(
        select(MedicalRecord).where(
            MedicalRecord.id.in_(source_record_ids),
            MedicalRecord.user_id == user_id,
            family_scope(MedicalRecord, family_member_id),
            MedicalRecord.is_deleted == False,  # noqa: E712
        )
    )).all()
    if not records:
        return None, set()

    blocks = []
    for r in records:
        if r.processing_status != "completed":
            blocks.append(f"=== ATTACHED DOCUMENT: {r.title} ===\nStill being processed by AI - full details aren't available yet.")
            continue

        header_bits = [r.title, r.record_type]
        if r.record_date:
            header_bits.append(str(r.record_date))
        parts = [f"=== ATTACHED DOCUMENT: {' | '.join(header_bits)} ==="]
        if r.issuing_organization:
            parts.append(f"Issued by: {r.issuing_organization}")
        if r.referring_doctor:
            parts.append(f"Referring doctor: {r.referring_doctor}")
        if r.ai_summary:
            parts.append(f"AI Summary: {r.ai_summary}")

        conditions = (await db.scalars(select(Condition).where(
            Condition.source_record_id == r.id, Condition.is_deleted == False,  # noqa: E712
        ))).all()
        if conditions:
            parts.append("Conditions: " + "; ".join(
                f"{c.condition_name} ({c.clinical_status})" for c in conditions
            ))

        medications = (await db.scalars(select(MedicationRequest).where(
            MedicationRequest.source_record_id == r.id, MedicationRequest.is_deleted == False,  # noqa: E712
        ))).all()
        if medications:
            parts.append("Medications: " + "; ".join(
                f"{m.medication_name_raw} {m.dosage_instruction or ''} {m.dose_frequency or ''}".strip()
                for m in medications
            ))

        observations = (await db.scalars(select(Observation).where(
            Observation.source_record_id == r.id, Observation.is_deleted == False,  # noqa: E712
        ))).all()
        if observations:
            parts.append("Lab Results/Vitals: " + "; ".join(
                f"{o.observation_name} "
                f"{o.value_quantity if o.value_quantity is not None else (o.value_string or '')} "
                f"{o.value_unit or ''}".strip()
                for o in observations
            ))

        allergies = (await db.scalars(select(AllergyIntolerance).where(
            AllergyIntolerance.source_record_id == r.id, AllergyIntolerance.is_deleted == False,  # noqa: E712
        ))).all()
        if allergies:
            parts.append("Allergies: " + "; ".join(
                a.substance_name + (f" (reaction: {a.reaction_description})" if a.reaction_description else "")
                for a in allergies
            ))

        encounters = (await db.scalars(select(Encounter).where(
            Encounter.source_record_id == r.id, Encounter.is_deleted == False,  # noqa: E712
        ))).all()
        if encounters:
            parts.append("Visits: " + "; ".join(
                e.title + (f" with {e.practitioner_name}" if e.practitioner_name else "")
                for e in encounters
            ))

        blocks.append("\n".join(parts))

    header = (
        "ATTACHED DOCUMENT(S) - the patient explicitly attached these to this question. This is "
        "everything stored about them. Always treat these as exactly what the patient means by "
        "\"this\"/\"this document\"/\"it\":"
    )
    return f"{header}\n\n" + "\n\n".join(blocks), {r.id for r in records}


async def resolve_citations(db: AsyncSession, record_ids: set[str]) -> dict[str, Citation]:
    """
    Resolves grounding record IDs to citation display data in one query. Live-resolved (not
    snapshotted at message time) so a renamed record shows its current title; soft-deleted
    records are silently dropped rather than citing something the patient can no longer open.
    """
    if not record_ids:
        return {}
    records = (await db.scalars(
        select(MedicalRecord).where(
            MedicalRecord.id.in_(uuid.UUID(r) for r in record_ids),
            MedicalRecord.is_deleted == False,  # noqa: E712
        )
    )).all()
    return {
        str(r.id): Citation(record_id=r.id, title=r.title, record_type=r.record_type, record_date=r.record_date)
        for r in records
    }
