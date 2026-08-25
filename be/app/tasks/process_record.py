"""
Background task: download document from S3, extract content (text or Vision LLM for images/
scanned PDFs), standardize codes via official terminology APIs, persist structured clinical
data, and update the record status.
Runs via FastAPI BackgroundTasks - no Celery/Redis required.
"""
import difflib
import io
import re
import uuid
import boto3
from botocore.exceptions import ClientError
from datetime import datetime, timezone
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from app.models.clinical import Condition
from app.models.clinical import Encounter
from app.models.clinical import AllergyIntolerance
from app.models.clinical import Observation
from sqlalchemy import func, select
from app.models.clinical import Medication, MedicationRequest
from app.models.clinical import AllergyIntolerance, Condition, Encounter, Medication, MedicationRequest, Observation
from app.models.family import FamilyMember
from app.models.profile import UserProfile
from app.models.records import MedicalRecord
from app.models.settings import AppSetting
from app.core.enums import Language
from app.services.openrouter import analyze_observations, extract_from_image, extract_medical_data, summarize_document
from app.services.record_retrieval import index_record
from app.services.terminology import standardize_extracted
import structlog
from pypdf import PdfReader
import fitz
from app.config import settings

logger = structlog.get_logger()


async def process_record(record_id: str) -> dict:
    pipeline_start = datetime.now(timezone.utc)
    logger.info("Record processing pipeline started", record_id=record_id)

    engine = create_async_engine(
        settings.DATABASE_URL,
        pool_size=2,
        pool_pre_ping=True,
        connect_args={"ssl": True} if settings.DATABASE_SSL else {},
    )

    AsyncSession_ = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    try:
        async with AsyncSession_() as db:

            record = await db.scalar(
                select(MedicalRecord).where(MedicalRecord.id == uuid.UUID(record_id))
            )

            if not record:
                logger.error("Record not found - aborting pipeline", record_id=record_id)
                return {"status": "error", "reason": "record_not_found"}

            logger.debug(
                "Record loaded",
                record_id=record_id,
                file_mime_type=record.file_mime_type,
                file_key=record.file_key,
            )

            # ── 1. Download + extract content ──────────────────────────────────
            logger.info("Pipeline stage 1/8 - content extraction started", record_id=record_id)
            document_text, pre_extraction = await _extract_content_from_s3(
                record.file_key, record.file_mime_type, record.user_id, record.family_member_id
            )

            if document_text is None:
                record.processing_status = "failed"
                record.processing_error = "Could not extract content from document"
                await db.commit()
                logger.warning("Pipeline aborted - content extraction failed", record_id=record_id)
                return {"status": "failed"}
            record.extracted_text = document_text
            logger.debug(
                "Pipeline stage 1/8 - content extraction completed",
                record_id=record_id,
                document_chars=len(document_text),
                used_vision_llm=pre_extraction is not None,
            )

            # ── 2. AI extraction (skip if Vision LLM already ran) ──────────────
            logger.info("Pipeline stage 2/8 - AI extraction started", record_id=record_id)
            if pre_extraction is not None:
                extraction_result = pre_extraction
                logger.debug("Pipeline stage 2/8 - reusing Vision LLM extraction result", record_id=record_id)
            else:
                extraction_result = await extract_medical_data(
                    document_text, user_id=record.user_id, family_member_id=record.family_member_id
                )

            extracted = extraction_result.get("extracted", {})

            # Reject documents the extraction model itself identified as not a medical record
            # (random photos, invoices, screenshots, etc.) before persisting anything derived
            # from them. Missing/unparseable flag defaults to allowing the record through - an
            # extraction miss on this one field must not block a genuine medical document.
            if extracted.get("is_medical_document") is False:
                record.processing_status = "failed"
                record.processing_error = (
                    "This document doesn't appear to be a medical record (prescription, lab "
                    "report, or similar). Please upload a genuine medical document."
                )
                await db.commit()
                duration_ms = round((datetime.now(timezone.utc) - pipeline_start).total_seconds() * 1000, 2)
                logger.warning(
                    "Pipeline aborted - document not medical", record_id=record_id, duration_ms=duration_ms
                )
                return {"status": "failed", "reason": "not_medical_document"}

            # ── 3. Terminology standardization ─────────────────────────────────
            logger.info("Pipeline stage 3/8 - terminology standardization started", record_id=record_id)
            extracted = await standardize_extracted(extracted)

            # ── 4. Persist clinical entities ────────────────────────────────────
            logger.info("Pipeline stage 4/8 - persisting clinical entities", record_id=record_id)
            user_id          = record.user_id
            family_member_id = record.family_member_id
            source_record_id = record.id

            await _persist_conditions(db, extracted.get("conditions", []), user_id, family_member_id, source_record_id)
            await _persist_medications(db, extracted.get("medications", []), user_id, family_member_id, source_record_id)
            await _persist_observations(db, extracted.get("observations", []), user_id, family_member_id, source_record_id)
            await _persist_allergies(db, extracted.get("allergies", []), user_id, family_member_id, source_record_id)
            await _persist_encounters(db, extracted.get("encounters", []), user_id, family_member_id, source_record_id)
            logger.debug(
                "Pipeline stage 4/8 - clinical entities persisted",
                record_id=record_id,
                conditions=len(extracted.get("conditions", [])),
                medications=len(extracted.get("medications", [])),
                observations=len(extracted.get("observations", [])),
                allergies=len(extracted.get("allergies", [])),
                encounters=len(extracted.get("encounters", [])),
            )

            # ── 4b. RAG indexing - chunk + embed the structured extraction for AI chat retrieval ──
            # Uses the same `extracted` dict just persisted above, not raw document_text: it's
            # already clean, fact-dense, and complete (no separate LLM call needed for this).
            logger.info("Pipeline stage 4b/8 - RAG indexing started", record_id=record_id)
            try:
                await index_record(db, record, extracted, document_text)
            except Exception as exc:
                logger.warning("RAG indexing failed - continuing pipeline", record_id=record_id, error=str(exc))

            # ── 5. AI-suggested title and record_type ─────────────────────────
            logger.info("Pipeline stage 5/8 - applying AI-suggested metadata", record_id=record_id)
            from app.schemas.records import VALID_RECORD_TYPES

            ai_title = extracted.get("document_title")
            if ai_title and record.title in ("Untitled", "", None):
                record.title = str(ai_title)[:255]
                logger.debug("AI-suggested title applied", record_id=record_id, title=record.title)

            ai_type = extracted.get("document_type")
            if ai_type and ai_type in VALID_RECORD_TYPES and record.record_type in ("other", "", None):
                record.record_type = ai_type
                logger.debug("AI-suggested record_type applied", record_id=record_id, record_type=ai_type)

            # ── Look up the patient's saved language preference (used by both stages below) ──
            user_language = await db.scalar(
                select(AppSetting.language).where(AppSetting.user_id == record.user_id)
            )
            language = Language(user_language) if user_language else Language.EN

            # ── 6. Structured health analysis (observations → parameter cards) ──
            observations = extracted.get("observations", [])
            if observations:
                logger.info("Pipeline stage 6/8 - observation analysis started", record_id=record_id)
                analysis_result = await analyze_observations(
                    observations,
                    language=language,
                    user_id=record.user_id,
                    family_member_id=record.family_member_id,
                )
                record.ai_analysis = analysis_result.get("analysis")
            else:
                logger.debug("Pipeline stage 6/8 - skipped, no observations to analyze", record_id=record_id)

            # ── 7. AI summary ──────────────────────────────────────────────────
            logger.info("Pipeline stage 7/8 - AI summary generation started", record_id=record_id)
            summary_result = await summarize_document(
                document_text,
                record.record_type,
                language=language,
                user_id=record.user_id,
                family_member_id=record.family_member_id,
            )

            # ── 8. Update record ───────────────────────────────────────────────
            logger.info("Pipeline stage 8/8 - finalizing record", record_id=record_id)
            record.ai_summary = summary_result.get("summary")
            record.ai_summary_generated_at = datetime.now(timezone.utc)
            record.ai_summary_model_version = extraction_result.get("model", "")

            if extracted.get("patient_name"):
                record.patient_name_on_doc = extracted["patient_name"]

            # Flag documents whose printed patient name doesn't match the profile they were
            # uploaded against, instead of silently filing someone else's document under this
            # patient's record. Only acts when both names are actually known - an AI extraction
            # miss (no name found) must not block the upload.
            owner_name = await _resolve_owner_name(db, record.user_id, record.family_member_id)
            if extracted.get("patient_name") and owner_name and not _names_match(extracted["patient_name"], owner_name):
                record.processing_status = "failed"
                record.processing_error = (
                    f"Patient name on document (\"{extracted['patient_name']}\") does not match "
                    f"the profile it was uploaded to (\"{owner_name}\")."
                )
                await db.commit()
                duration_ms = round((datetime.now(timezone.utc) - pipeline_start).total_seconds() * 1000, 2)
                logger.warning(
                    "Pipeline aborted - patient name mismatch",
                    record_id=record_id,
                    document_name=extracted["patient_name"],
                    profile_name=owner_name,
                    duration_ms=duration_ms,
                )
                return {"status": "failed", "reason": "patient_name_mismatch"}

            record.processing_status = "completed"

            if extracted.get("issuing_organization"):
                record.issuing_organization = extracted["issuing_organization"]

            # Persist the AI-extracted document date instead of letting it evaporate after
            # being folded into the summary text — NULL (parse failure/absent) is left as-is,
            # never guessed, since an unknown document date must not be assumed recent.
            parsed_document_date = _parse_date(extracted.get("document_date"))
            if parsed_document_date:
                record.document_date = parsed_document_date

            await db.commit()
            duration_ms = round((datetime.now(timezone.utc) - pipeline_start).total_seconds() * 1000, 2)
            logger.info("Record processing pipeline completed", record_id=record_id, duration_ms=duration_ms)
            return {"status": "completed"}

    except Exception as exc:
        duration_ms = round((datetime.now(timezone.utc) - pipeline_start).total_seconds() * 1000, 2)
        logger.error(
            "Record processing pipeline failed",
            record_id=record_id,
            error=str(exc),
            duration_ms=duration_ms,
            exc_info=True,
        )
        async with AsyncSession_() as db:
            try:
                record = await db.scalar(
                    select(MedicalRecord).where(MedicalRecord.id == uuid.UUID(record_id))
                )
                if record:
                    record.processing_status = "failed"
                    record.processing_error = str(exc)[:500]
                    await db.commit()
                    logger.debug("Record marked as failed after pipeline exception", record_id=record_id)
            except Exception:
                logger.error("Failed to persist failure status after pipeline exception", record_id=record_id, exc_info=True)
        raise
    finally:
        await engine.dispose()


# ── Content extraction ─────────────────────────────────────────────────────────

async def _extract_content_from_s3(
    file_key: str, mime_type: str, user_id=None, family_member_id=None
) -> tuple[str | None, dict | None]:
    """
    Downloads from S3 and dispatches to the correct extraction path.
    Returns (document_text, pre_extraction_result).
    pre_extraction_result is non-None when Vision LLM already ran (images, scanned PDFs).
    document_text is always set (even for image paths - as a readable summary for summarization).
    """


    if not settings.AWS_ACCESS_KEY_ID:
        logger.warning("S3 not configured - using placeholder text", key=file_key)
        return f"[Sample document text for key: {file_key}]", None

    try:
        s3 = boto3.client(
            "s3",
            region_name=settings.AWS_DEFAULT_REGION,
            aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
            aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
        )
        obj = s3.get_object(Bucket=settings.AWS_S3_BUCKET_NAME, Key=file_key)
        file_bytes: bytes = obj["Body"].read()
        logger.debug("Downloaded document from S3", key=file_key, size_bytes=len(file_bytes))

    except ClientError as exc:
        logger.error("Failed to download from S3", key=file_key, error=str(exc))
        return None, None

    if mime_type.startswith("image/"):
        logger.debug("Dispatching to image extraction path", key=file_key, mime_type=mime_type)
        return await _extract_image(file_bytes, mime_type, user_id, family_member_id)
    elif mime_type == "application/pdf":
        logger.debug("Dispatching to PDF extraction path", key=file_key)
        return await _extract_pdf(file_bytes, user_id, family_member_id)
    elif mime_type in (
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        "application/msword",
    ):
        logger.debug("Dispatching to DOCX extraction path", key=file_key)
        return _extract_docx(file_bytes), None
    else:
        logger.debug("Dispatching to raw-text decode path", key=file_key, mime_type=mime_type)
        try:
            return file_bytes.decode("utf-8", errors="ignore"), None
        except Exception as exc:
            logger.warning("Raw-text decode failed", key=file_key, error=str(exc))
            return None, None


async def _extract_image(
    image_bytes: bytes, mime_type: str, user_id=None, family_member_id=None
) -> tuple[str | None, dict | None]:
    """Send image directly to Vision LLM. Returns (text_for_summary, extraction_result)."""

    extraction_result = await extract_from_image(image_bytes, mime_type, user_id, family_member_id)
    document_text     = _extraction_to_text(extraction_result.get("extracted", {}))
    return document_text, extraction_result


async def _extract_pdf(pdf_bytes: bytes, user_id=None, family_member_id=None) -> tuple[str | None, dict | None]:
    """
    Extract PDF content:
    - Text PDF  → pypdf text extraction → (text, None)
    - Scanned PDF → PyMuPDF page renders → Vision LLM per page → merged (text, extraction)
    """

    text_pages = _pypdf_extract(pdf_bytes)

    if text_pages is not None:
        total_chars = sum(len(p) for p in text_pages)
        avg_chars   = total_chars / max(len(text_pages), 1)
        logger.debug("PDF text layer extracted", pages=len(text_pages), avg_chars_per_page=round(avg_chars, 1))
        if avg_chars >= 80:
            return "\n".join(text_pages), None

    logger.info("Scanned PDF detected - using Vision LLM for page extraction")
    return await _extract_scanned_pdf(pdf_bytes, user_id, family_member_id)


def _pypdf_extract(pdf_bytes: bytes) -> list[str] | None:
    """Extract text from all pages. Returns list of page texts, or None on failure."""
    try:
        reader = PdfReader(io.BytesIO(pdf_bytes))
        return [page.extract_text() or "" for page in reader.pages]
    except ImportError:
        logger.warning("pypdf not installed - PDF text extraction unavailable")
        return None
    except Exception as exc:
        logger.warning("pypdf extraction failed", error=str(exc))
        return None


async def _extract_scanned_pdf(pdf_bytes: bytes, user_id=None, family_member_id=None) -> tuple[str | None, dict | None]:
    """Render each PDF page as JPEG and extract via Vision LLM. Limit to 5 pages."""


    try:
        doc = fitz.open(stream=pdf_bytes, filetype="pdf")
        page_limit = min(doc.page_count, 5)
        merged: dict = {}
        logger.debug("Scanned PDF page rendering started", total_pages=doc.page_count, pages_to_process=page_limit)

        for page_num in range(page_limit):
            page = doc.load_page(page_num)
            # 150 DPI is sufficient for medical text; keeps image size manageable
            pix = page.get_pixmap(dpi=150)
            jpeg_bytes = pix.tobytes(output="jpeg")

            logger.debug("Extracting scanned PDF page via Vision LLM", page_num=page_num + 1, of_pages=page_limit)
            result = await extract_from_image(jpeg_bytes, "image/jpeg", user_id, family_member_id)
            page_data = result.get("extracted", {})

            # Merge list fields
            for key in ("conditions", "medications", "observations", "allergies", "encounters"):
                merged.setdefault(key, [])
                merged[key].extend(page_data.get(key, []))

            # Take first non-null metadata
            for key in ("document_date", "patient_name", "issuing_organization", "document_title", "document_type"):
                if not merged.get(key) and page_data.get(key):
                    merged[key] = page_data[key]

        doc.close()

        extraction_result = {
            "extracted": merged,
            "model": settings.AI_EXTRACTION_MODEL,
            "prompt_tokens": 0,
            "completion_tokens": 0,
        }
        document_text = _extraction_to_text(merged)
        logger.debug("Scanned PDF page rendering completed", pages_processed=page_limit)
        return document_text, extraction_result

    except Exception as exc:
        logger.error("Scanned PDF Vision extraction failed", error=str(exc), exc_info=True)
        return None, None


def _extract_docx(docx_bytes: bytes) -> str | None:
    """Extract text from .docx using python-docx."""
    try:
        import docx
        doc = docx.Document(io.BytesIO(docx_bytes))
        paragraphs = [p.text for p in doc.paragraphs if p.text.strip()]
        logger.debug("DOCX extraction completed", paragraphs=len(paragraphs))
        return "\n".join(paragraphs)
    except ImportError:
        logger.warning("python-docx not installed - .docx extraction unavailable")
        return "[Word document - install python-docx for extraction]"
    except Exception as exc:
        logger.error("DOCX extraction failed", error=str(exc), exc_info=True)
        return None


def _extraction_to_text(extracted: dict) -> str:
    """Serialize extracted JSON to a readable paragraph for AI summarization."""
    parts = []

    conditions = extracted.get("conditions", [])
    if conditions:
        parts.append("Conditions: " + ", ".join(c.get("name", "") for c in conditions))

    medications = extracted.get("medications", [])
    if medications:
        parts.append(
            "Medications: "
            + ", ".join(
                f"{m.get('name', '')} {m.get('dosage', '')}".strip()
                for m in medications
            )
        )

    observations = extracted.get("observations", [])
    if observations:
        parts.append(
            "Lab Results/Vitals: "
            + ", ".join(
                f"{o.get('name', '')} {o.get('value', '')} {o.get('unit', '')}".strip()
                for o in observations
            )
        )

    allergies = extracted.get("allergies", [])
    if allergies:
        parts.append("Allergies: " + ", ".join(a.get("substance", "") for a in allergies))

    if extracted.get("patient_name"):
        parts.append(f"Patient: {extracted['patient_name']}")
    if extracted.get("document_date"):
        parts.append(f"Document date: {extracted['document_date']}")
    if extracted.get("issuing_organization"):
        parts.append(f"Issued by: {extracted['issuing_organization']}")

    return " | ".join(parts) if parts else "[No structured data could be extracted from document]"


# ── Date helper ────────────────────────────────────────────────────────────────

def _parse_date(date_str: str | None):
    if not date_str:
        return None
    try:
        from datetime import date as date_type
        return date_type.fromisoformat(str(date_str)[:10])
    except (ValueError, TypeError):
        return None


async def _resolve_owner_name(db, user_id, family_member_id) -> str | None:
    """The name a document uploaded to this record should be printed under: the family member's
    name if this record belongs to a dependent profile, otherwise the account owner's own name."""
    if family_member_id:
        member = await db.scalar(select(FamilyMember).where(FamilyMember.id == family_member_id))
        return member.full_name if member else None

    profile = await db.scalar(select(UserProfile).where(UserProfile.user_id == user_id))
    return profile.full_name if profile else None


def _normalize_name(name: str) -> list[str]:
    cleaned = re.sub(r"[^a-z0-9\s]", " ", name.lower())
    return sorted(token for token in cleaned.split() if token)


_NAME_TOKEN_MATCH_RATIO = 0.72


def _token_matches_any(token: str, candidates: list[str]) -> bool:
    for candidate in candidates:
        if token == candidate:
            return True
        # A short token (initial, or a first two letters an OCR pass truncated to) counts as a
        # match if it's the start of a longer name - "m" / "es" should match "maryam" / "esha".
        if len(token) <= 2 and candidate.startswith(token):
            return True
        # Handwriting/OCR/staff transcription regularly swaps a letter or two in a name that
        # sounds the same ("Isha" vs "Esha", "Sohaib" vs "Suhaib") - a high per-token similarity
        # ratio catches that without being loose enough to accept an unrelated name.
        if difflib.SequenceMatcher(None, token, candidate).ratio() >= _NAME_TOKEN_MATCH_RATIO:
            return True
    return False


def _names_match(document_name: str, profile_name: str) -> bool:
    """Order/punctuation/case-insensitive, spelling-tolerant name comparison. Medical documents
    rarely carry someone's full legal name (often just a first name, an initial, or a phonetic
    misspelling from OCR/handwriting) - so this matches token-by-token rather than comparing the
    two names as whole strings, and only requires every token actually present on the document to
    correspond to some part of the profile name."""
    doc_tokens = _normalize_name(document_name)
    profile_tokens = _normalize_name(profile_name)
    if not doc_tokens or not profile_tokens:
        return True

    return all(_token_matches_any(token, profile_tokens) for token in doc_tokens)


# ── Persist helpers ────────────────────────────────────────────────────────────

async def _persist_conditions(db, conditions: list, user_id, family_member_id, source_record_id) -> None:

    valid_statuses = {"active", "recurrence", "relapse", "inactive", "remission", "resolved"}
    for item in conditions[:50]:
        status = item.get("status", "active")
        db.add(Condition(
            user_id=user_id,
            family_member_id=family_member_id,
            condition_name=item.get("name"),
            clinical_status=status if status in valid_statuses else "active",
            icd11_code=item.get("icd11_code"),
            icd11_display=item.get("icd11_display") or item.get("name"),
            snomed_code=item.get("snomed_code"),
            snomed_display=item.get("snomed_display"),
            onset_date=_parse_date(item.get("onset_date")),
            source="ai_extracted",
            source_record_id=source_record_id,
            ai_extracted=True,
            ai_confidence=0.8,
        ))


async def _persist_medications(db, medications: list, user_id, family_member_id, source_record_id) -> None:

    valid_statuses = {"active", "on-hold", "cancelled", "completed", "entered-in-error", "stopped", "draft", "unknown"}

    for item in medications[:50]:
        # Documents rarely state an explicit FHIR status, and this field no longer
        # drives any "active medication" UI (that's keyed off MedicationReminder) -
        # so an unstated/invalid status is recorded honestly as "unknown", not guessed.
        raw_status = item.get("status", "unknown")
        med_name = item.get("name")
        atc_code = item.get("atc_code")
        atc_display = item.get("atc_display")
        medication_id = None

        # Upsert into the Medication catalog if we have an ATC code
        if atc_code:
            med_row = await db.scalar(
                select(Medication).where(func.lower(Medication.name) == med_name.lower())
            )
            if med_row:
                if not med_row.atc_code:
                    med_row.atc_code = atc_code
                    med_row.atc_display = atc_display
                medication_id = med_row.id
            else:
                new_med = Medication(name=med_name, atc_code=atc_code, atc_display=atc_display)
                db.add(new_med)
                await db.flush()
                medication_id = new_med.id

        db.add(MedicationRequest(
            user_id=user_id,
            family_member_id=family_member_id,
            medication_id=medication_id,
            medication_name_raw=med_name,
            dosage_instruction=item.get("dosage"),
            dose_frequency=item.get("frequency"),
            status=raw_status if raw_status in valid_statuses else "unknown",
            intent="order",
            prescribed_date=_parse_date(item.get("date")),
            source_record_id=source_record_id,
            ai_extracted=True,
            ai_confidence=0.8,
        ))


async def _persist_observations(db, observations: list, user_id, family_member_id, source_record_id) -> None:

    valid_categories = {"vital-signs", "laboratory", "imaging", "procedure", "survey", "exam", "therapy", "activity"}

    for item in observations[:50]:
        category = item.get("category", "laboratory")
        if category not in valid_categories:
            category = "laboratory"

        value = item.get("value")
        value_quantity = None
        value_string = None
        try:
            value_quantity = float(str(value).split()[0])
        except (ValueError, TypeError, AttributeError):
            value_string = str(value) if value else None

        db.add(Observation(
            user_id=user_id,
            family_member_id=family_member_id,
            observation_name=item.get("name"),
            observation_category=category,
            loinc_code=item.get("loinc_code"),
            loinc_display=item.get("loinc_display"),
            value_quantity=value_quantity,
            value_unit=item.get("unit"),
            value_string=value_string,
            status="final",
            source_record_id=source_record_id,
            ai_extracted=True,
            ai_confidence=0.8,
        ))


async def _persist_allergies(db, allergies: list, user_id, family_member_id, source_record_id) -> None:

    valid_criticality = {"low", "high", "unable-to-assess"}
    for item in allergies[:50]:
        criticality = item.get("criticality")
        db.add(AllergyIntolerance(
            user_id=user_id,
            family_member_id=family_member_id,
            substance_name=item.get("substance"),
            snomed_code=item.get("snomed_code"),
            snomed_display=item.get("snomed_display"),
            criticality=criticality,
            reaction_description=item.get("reaction"),
            clinical_status="active",
            verification_status="unconfirmed",
            source="ai_extracted",
            source_record_id=source_record_id,
            ai_extracted=True,
            ai_confidence=0.8,
        ))


async def _persist_encounters(db, encounters: list, user_id, family_member_id, source_record_id) -> None:

    valid_types = {"ambulatory", "emergency", "inpatient", "home-health", "virtual", "observation", "vaccination"}
    for item in encounters[:50]:
        enc_type = item.get("type")
        if enc_type not in valid_types:
            enc_type = "observation"
        encounter_date = _parse_date(item.get("date"))
        db.add(Encounter(
            user_id=user_id,
            family_member_id=family_member_id,
            encounter_type=enc_type,
            status="finished",
            title=f"Visit - {item.get('practitioner', 'Unknown')}",
            practitioner_name=item.get("practitioner"),
            organization_name=item.get("organization"),
            start_datetime=(
                datetime.combine(encounter_date, datetime.min.time(), tzinfo=timezone.utc)
                if encounter_date
                else None
            ),
            source_record_id=source_record_id,
            ai_extracted=True,
            ai_confidence=0.8,
        ))
