"""
RAG retrieval for AI chat (Phase 2) - chunk + embed a document at ingestion time, retrieve
semantically-relevant chunks at chat time. Scoped strictly per patient via
core.scoping.family_scope, same rule used everywhere else patient data is queried.

Embedding source is the structured clinical extraction (conditions/medications/observations/
allergies/encounters), not raw OCR/document text: it's already clean (extraction rules forbid
inference/noise), complete (every item, not just headline findings like ai_summary), and free
(the extraction LLM call already runs for every document regardless of RAG). One chunk per
fact/entity gives precise, structure-aware retrieval instead of blind fixed-size text slicing.
Raw-text chunking is kept only as a fallback for documents the extraction schema can't capture.
"""
import uuid

import structlog
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.scoping import family_scope
from app.models.records import MedicalRecord, RecordChunk
from app.services.openrouter import get_embeddings

logger = structlog.get_logger()

_CHUNK_SIZE = 1000       # fallback raw-text chunking only
_CHUNK_OVERLAP = 150
_TOP_K = 5
_MIN_SIMILARITY = 0.55


def _fact(*parts: str | None) -> str:
    return ", ".join(p for p in parts if p) + "."


def _extraction_to_chunks(extracted: dict) -> list[str]:
    """
    Renders the structured clinical extraction into dense, self-contained, one-fact-per-chunk
    sentences. Each entity becomes its own chunk so retrieval can point at the exact fact
    (e.g. one specific lab value) instead of an arbitrary slice of raw text.
    """
    chunks: list[str] = []

    meta = _fact(
        f"Document: {extracted['document_title']}" if extracted.get("document_title") else None,
        f"Type: {extracted['document_type']}" if extracted.get("document_type") else None,
        f"Date: {extracted['document_date']}" if extracted.get("document_date") else None,
        f"Patient: {extracted['patient_name']}" if extracted.get("patient_name") else None,
        f"Issued by: {extracted['issuing_organization']}" if extracted.get("issuing_organization") else None,
        f"Referring doctor: {extracted['referring_doctor']}" if extracted.get("referring_doctor") else None,
    )
    if meta != ".":
        chunks.append(meta)

    for c in extracted.get("conditions", []):
        if not c.get("name"):
            continue
        chunks.append(_fact(
            f"Condition: {c['name']}",
            f"status {c['status']}" if c.get("status") else None,
            f"severity {c['severity']}" if c.get("severity") else None,
            f"onset {c['onset_date']}" if c.get("onset_date") else None,
        ))

    for m in extracted.get("medications", []):
        if not m.get("name"):
            continue
        chunks.append(_fact(
            f"Medication: {m['name']}",
            m.get("dosage"),
            m.get("frequency"),
            f"route {m['route']}" if m.get("route") else None,
            f"status {m['status']}" if m.get("status") else None,
            f"prescribed {m['date']}" if m.get("date") else None,
        ))

    for o in extracted.get("observations", []):
        if not o.get("name"):
            continue
        value = " ".join(str(v) for v in (o.get("value"), o.get("unit")) if v)
        chunks.append(_fact(
            f"Observation: {o['name']}",
            value or None,
            f"interpretation {o['interpretation']}" if o.get("interpretation") else None,
            f"reference range {o['reference_range']}" if o.get("reference_range") else None,
            f"date {o['date']}" if o.get("date") else None,
        ))

    for a in extracted.get("allergies", []):
        if not a.get("substance"):
            continue
        chunks.append(_fact(
            f"Allergy: {a['substance']}",
            f"criticality {a['criticality']}" if a.get("criticality") else None,
            f"reaction {a['reaction']}" if a.get("reaction") else None,
        ))

    for e in extracted.get("encounters", []):
        if not e.get("type"):
            continue
        chunks.append(_fact(
            f"Encounter: {e['type']}",
            f"with {e['practitioner']}" if e.get("practitioner") else None,
            f"specialty {e['specialty']}" if e.get("specialty") else None,
            f"at {e['organization']}" if e.get("organization") else None,
            f"on {e['date']}" if e.get("date") else None,
        ))

    return chunks


def _chunk_text(text: str) -> list[str]:
    """Fallback raw-text chunking - only used when structured extraction yields nothing."""
    text = text.strip()
    if not text:
        return []
    chunks = []
    start = 0
    while start < len(text):
        end = start + _CHUNK_SIZE
        chunks.append(text[start:end])
        if end >= len(text):
            break
        start = end - _CHUNK_OVERLAP
    return chunks


async def index_record(db: AsyncSession, record: MedicalRecord, extracted: dict, document_text: str) -> None:
    """
    Chunk + embed a document for RAG retrieval and stage RecordChunk rows on the session
    (caller commits). Prefers structure-aware chunks built from the extraction; falls back to
    naive raw-text chunking only when extraction produced nothing (e.g. a document type the
    schema doesn't capture). Best-effort: embedding failures are logged and swallowed so a RAG
    outage never fails document ingestion.
    """
    structured_chunks = _extraction_to_chunks(extracted)
    chunks = structured_chunks or _chunk_text(document_text)
    if not chunks:
        return

    try:
        vectors = await get_embeddings(
            chunks,
            feature="embedding_index",
            user_id=record.user_id,
            family_member_id=record.family_member_id,
        )
    except Exception as exc:
        logger.warning("Record chunk embedding failed - skipping RAG indexing", record_id=str(record.id), error=str(exc))
        return

    for index, (chunk, vector) in enumerate(zip(chunks, vectors)):
        db.add(RecordChunk(
            record_id=record.id,
            user_id=record.user_id,
            family_member_id=record.family_member_id,
            chunk_index=index,
            chunk_text=chunk,
            embedding=vector,
        ))
    logger.debug(
        "Record chunks indexed for RAG",
        record_id=str(record.id),
        chunk_count=len(chunks),
        source="structured_extraction" if structured_chunks else "raw_text_fallback",
    )


async def retrieve_relevant_chunks(
    db: AsyncSession,
    user_id: uuid.UUID,
    family_member_id: uuid.UUID | None,
    query_text: str,
    top_k: int = _TOP_K,
) -> list[dict]:
    """
    Semantic search over the scoped patient's document chunks, for open-ended questions with no
    explicitly attached document (that case is handled separately - see
    ai_chat._build_attached_records_context, which feeds full document data directly instead of
    guessing via similarity). Only returns matches above _MIN_SIMILARITY so irrelevant chunks
    don't pollute context on generic questions.
    """
    if not query_text.strip():
        return []

    try:
        [query_vector] = await get_embeddings(
            [query_text],
            feature="embedding_query",
            user_id=user_id,
            family_member_id=family_member_id,
        )
    except Exception as exc:
        logger.warning("Chat query embedding failed - skipping RAG retrieval", error=str(exc))
        return []
    if not any(query_vector):
        return []

    distance = RecordChunk.embedding.cosine_distance(query_vector)
    stmt = (
        select(RecordChunk, MedicalRecord.title, MedicalRecord.record_date, distance.label("distance"))
        .join(MedicalRecord, MedicalRecord.id == RecordChunk.record_id)
        .where(
            RecordChunk.user_id == user_id,
            family_scope(RecordChunk, family_member_id),
            MedicalRecord.is_deleted == False,  # noqa: E712
        )
        .order_by(distance)
        .limit(top_k)
    )

    rows = (await db.execute(stmt)).all()

    results = []
    for chunk, title, record_date, dist in rows:
        similarity = 1 - float(dist)
        if similarity < _MIN_SIMILARITY:
            continue
        results.append({
            "record_id": chunk.record_id,
            "record_title": title,
            "record_date": record_date,
            "chunk_text": chunk.chunk_text,
            "similarity": similarity,
        })
    return results


def format_chunks_for_prompt(chunks: list[dict]) -> str:
    parts = []
    for c in chunks:
        citation = c["record_title"] or "Untitled record"
        if c["record_date"]:
            citation += f" ({c['record_date']})"
        parts.append(f"[{citation}]\n{c['chunk_text']}")
    return "\n\n".join(parts)
