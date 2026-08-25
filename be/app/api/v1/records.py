import mimetypes
import uuid
from datetime import datetime, timezone

import structlog
from fastapi import APIRouter, BackgroundTasks, Query, status
from sqlalchemy import delete as sa_delete, func, select, text, update as sa_update

from app.config import settings
from app.core.encryption import decrypt_jsonb_row
from app.core.errors import ApiError, ErrorCode
from app.core.scoping import family_scope, validate_family_member_ownership
from app.dependencies import CurrentUser, DB
from app.models.records import MedicalRecord, RecordChunk, RecordFolder
from app.schemas.records import (
    FolderCreateRequest,
    FolderOut,
    FolderUpdateRequest,
    RecordClinicalOut,
    RecordConfirmUploadRequest,
    RecordFullOut,
    RecordOut,
    RecordUpdateRequest,
    RecordUploadInitRequest,
    RecordUploadInitResponse,
    VALID_RECORD_TYPES,
)
from app.services.s3_service import s3_service

logger = structlog.get_logger()

router = APIRouter(prefix="/records", tags=["records"])


def _download_filename(title: str, mime_type: str) -> str:
    ext = mimetypes.guess_extension(mime_type) or ""
    return f"{title}{ext}"


# ── Folders ───────────────────────────────────────────────────────────────────

@router.get("/folders", response_model=list[FolderOut])
async def list_folders(current_user: CurrentUser, db: DB):
    folders = (await db.scalars(
        select(RecordFolder).where(
            RecordFolder.user_id == current_user.id,
            RecordFolder.is_deleted == False,  # noqa: E712
        ).order_by(RecordFolder.sort_order.asc(), RecordFolder.created_at.asc())
    )).all()
    return [FolderOut.model_validate(f) for f in folders]


@router.post("/folders", response_model=FolderOut, status_code=status.HTTP_201_CREATED)
async def create_folder(body: FolderCreateRequest, current_user: CurrentUser, db: DB):
    folder = RecordFolder(
        user_id=current_user.id,
        name=body.name,
        icon=body.icon,
        sort_order=body.sort_order,
    )
    db.add(folder)
    await db.commit()
    await db.refresh(folder)
    logger.info("Folder created", folder_id=str(folder.id), user_id=str(current_user.id))
    return FolderOut.model_validate(folder)


@router.patch("/folders/{folder_id}", response_model=FolderOut)
async def update_folder(folder_id: uuid.UUID, body: FolderUpdateRequest, current_user: CurrentUser, db: DB):
    folder = await db.scalar(
        select(RecordFolder).where(
            RecordFolder.id == folder_id,
            RecordFolder.user_id == current_user.id,
            RecordFolder.is_deleted == False,  # noqa: E712
        )
    )
    if not folder:
        raise ApiError(status_code=status.HTTP_404_NOT_FOUND, detail="Folder not found", error_code=ErrorCode.FOLDER_NOT_FOUND)

    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(folder, field, value)

    await db.commit()
    await db.refresh(folder)
    return FolderOut.model_validate(folder)


@router.delete("/folders/{folder_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_folder(folder_id: uuid.UUID, current_user: CurrentUser, db: DB):
    folder = await db.scalar(
        select(RecordFolder).where(
            RecordFolder.id == folder_id,
            RecordFolder.user_id == current_user.id,
            RecordFolder.is_deleted == False,  # noqa: E712
        )
    )
    if not folder:
        raise ApiError(status_code=status.HTTP_404_NOT_FOUND, detail="Folder not found", error_code=ErrorCode.FOLDER_NOT_FOUND)

    folder.is_deleted = True
    folder.deleted_at = datetime.now(timezone.utc)
    folder.deleted_by_id = current_user.id
    await db.commit()
    logger.info("Folder soft-deleted", folder_id=str(folder_id), user_id=str(current_user.id))


# ── Medical Records ───────────────────────────────────────────────────────────

@router.get("", response_model=list[RecordOut], summary="List records (optionally filtered)")
async def list_records(
    current_user: CurrentUser,
    db: DB,
    folder_id: uuid.UUID | None = None,
    record_type: str | None = None,
    family_member_id: uuid.UUID | None = None,
    limit: int = Query(50, le=200),
    offset: int = 0,
):
    query = select(MedicalRecord).where(
        MedicalRecord.user_id == current_user.id,
        MedicalRecord.is_deleted == False,  # noqa: E712
        family_scope(MedicalRecord, family_member_id),
    )
    if folder_id:
        query = query.where(MedicalRecord.folder_id == folder_id)
    if record_type:
        if record_type not in VALID_RECORD_TYPES:
            raise ApiError(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid record_type", error_code=ErrorCode.INVALID_RECORD_TYPE)
        query = query.where(MedicalRecord.record_type == record_type)

    # Order by the document's own date (extracted from its contents) when known, falling
    # back to upload time for records still processing or whose date couldn't be extracted —
    # NULL document_date must never be treated as "no date" and sorted as if recent.
    query = query.order_by(
        MedicalRecord.document_date.desc().nulls_last(), MedicalRecord.uploaded_at.desc()
    ).limit(limit).offset(offset)
    records = (await db.scalars(query)).all()

    result = []
    for r in records:
        out = RecordOut.model_validate(r)
        out.download_url = await s3_service.generate_presigned_download_url(
            r.file_key, download_filename=_download_filename(r.title, r.file_mime_type)
        )
        result.append(out)
    return result


@router.post(
    "/upload/init",
    response_model=RecordUploadInitResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Initiate a direct-to-S3 upload - returns pre-signed PUT URL",
)
async def init_upload(body: RecordUploadInitRequest, current_user: CurrentUser, db: DB):
    logger.debug(
        "Upload init requested",
        user_id=str(current_user.id),
        file_name=body.file_name,
        file_mime_type=body.file_mime_type,
        file_size_bytes=body.file_size_bytes,
    )
    if body.file_mime_type not in settings.allowed_mime_types_list:
        logger.warning("Upload rejected - unsupported mime type", file_mime_type=body.file_mime_type)
        raise ApiError(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unsupported file type: {body.file_mime_type}",
            error_code=ErrorCode.UNSUPPORTED_FILE_TYPE,
        )
    if body.file_size_bytes > settings.max_file_size_bytes:
        logger.warning("Upload rejected - file too large", file_size_bytes=body.file_size_bytes)
        raise ApiError(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"File too large. Max size: {settings.MAX_FILE_SIZE_MB} MB",
            error_code=ErrorCode.FILE_TOO_LARGE,
        )
    await validate_family_member_ownership(db, current_user.id, body.family_member_id)

    object_key = s3_service.generate_object_key(
        current_user.id, f"records/{body.record_type}", body.file_name
    )
    upload_post = await s3_service.generate_presigned_upload_post(
        object_key, body.file_mime_type, settings.max_file_size_bytes
    )

    record = MedicalRecord(
        user_id=current_user.id,
        family_member_id=body.family_member_id,
        folder_id=body.folder_id,
        title=body.title,
        record_type=body.record_type,
        record_date=body.record_date,
        file_key=object_key,
        file_name=body.file_name,
        file_mime_type=body.file_mime_type,
        file_size_bytes=body.file_size_bytes,
        processing_status="pending",
        is_dicom=body.file_mime_type == "application/dicom",
    )
    db.add(record)
    await db.commit()
    await db.refresh(record)
    logger.info("Record created (upload pending)", record_id=str(record.id), user_id=str(current_user.id), object_key=object_key)

    return RecordUploadInitResponse(
        record_id=record.id,
        upload_url=upload_post["url"],
        upload_fields=upload_post["fields"],
        object_key=object_key,
        expires_in_seconds=settings.AWS_S3_PRESIGNED_URL_EXPIRY_SECONDS,
    )


@router.post(
    "/{record_id}/upload/confirm",
    response_model=RecordOut,
    summary="Confirm upload complete - triggers AI extraction pipeline",
)
async def confirm_upload(
    record_id: uuid.UUID,
    body: RecordConfirmUploadRequest,
    background_tasks: BackgroundTasks,
    current_user: CurrentUser,
    db: DB,
):
    record = await _get_record_or_404(db, record_id, current_user.id)

    # Size enforcement lives at the S3 policy level now (see init_upload's presigned POST
    # with a content-length-range condition) - S3 rejects an oversized upload outright before
    # it ever lands, so there's nothing left to verify here post-hoc.
    if body.file_hash:
        duplicate = await db.scalar(
            select(MedicalRecord.id).where(
                MedicalRecord.user_id == current_user.id,
                MedicalRecord.file_hash == body.file_hash,
                MedicalRecord.id != record_id,
                MedicalRecord.is_deleted == False,  # noqa: E712
            )
        )
        if duplicate:
            logger.info(
                "Upload rejected - duplicate of an existing record",
                record_id=str(record_id), duplicate_of=str(duplicate), user_id=str(current_user.id),
            )
            raise ApiError(
                status_code=status.HTTP_409_CONFLICT,
                detail="This document has already been uploaded.",
                error_code=ErrorCode.DUPLICATE_RECORD,
            )
        record.file_hash = body.file_hash

    record.processing_status = "processing"
    await db.commit()
    logger.info("Upload confirmed - queuing AI processing pipeline", record_id=str(record_id), user_id=str(current_user.id))

    from app.tasks.process_record import process_record
    background_tasks.add_task(process_record, str(record_id))

    await db.refresh(record)
    out = RecordOut.model_validate(record)
    out.download_url = await s3_service.generate_presigned_download_url(
        record.file_key, download_filename=_download_filename(record.title, record.file_mime_type)
    )
    return out


@router.get("/{record_id}", response_model=RecordOut)
async def get_record(record_id: uuid.UUID, current_user: CurrentUser, db: DB):
    record = await _get_record_or_404(db, record_id, current_user.id)
    out = RecordOut.model_validate(record)
    out.download_url = await s3_service.generate_presigned_download_url(
        record.file_key, download_filename=_download_filename(record.title, record.file_mime_type)
    )
    return out


@router.patch("/{record_id}", response_model=RecordOut)
async def update_record(
    record_id: uuid.UUID, body: RecordUpdateRequest, current_user: CurrentUser, db: DB
):
    record = await _get_record_or_404(db, record_id, current_user.id)
    update_data = body.model_dump(exclude_unset=True)
    if update_data.get("folder_id") is not None:
        folder_exists = await db.scalar(
            select(RecordFolder.id).where(
                RecordFolder.id == update_data["folder_id"],
                RecordFolder.user_id == current_user.id,
                RecordFolder.is_deleted == False,  # noqa: E712
            )
        )
        if not folder_exists:
            raise ApiError(status_code=status.HTTP_404_NOT_FOUND, detail="Folder not found", error_code=ErrorCode.FOLDER_NOT_FOUND)
    for field, value in update_data.items():
        setattr(record, field, value)
    await db.commit()
    await db.refresh(record)

    out = RecordOut.model_validate(record)
    out.download_url = await s3_service.generate_presigned_download_url(
        record.file_key, download_filename=_download_filename(record.title, record.file_mime_type)
    )
    return out


@router.delete("/{record_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_record(record_id: uuid.UUID, current_user: CurrentUser, db: DB):
    record = await _get_record_or_404(db, record_id, current_user.id)
    now = datetime.now(timezone.utc)

    record.is_deleted = True
    record.deleted_at = now
    record.deleted_by_id = current_user.id
    record.deletion_type = "user_requested"

    # Cascade the soft-delete to every clinical entity extracted from this record, so it
    # immediately disappears from AI context, health summaries, the emergency card, and
    # every other place that queries clinical tables by is_deleted alone (i.e. everywhere) -
    # without this, deleting a record left its extracted data behind as if it still existed.
    from app.models.clinical import AllergyIntolerance, Condition, Encounter, MedicationRequest, Observation

    for model in (Condition, MedicationRequest, Observation, AllergyIntolerance, Encounter):
        await db.execute(
            sa_update(model)
            .where(
                model.user_id == current_user.id,
                model.source_record_id == record_id,
                model.is_deleted == False,  # noqa: E712
            )
            .values(is_deleted=True, deleted_at=now, deleted_by_id=current_user.id)
        )

    # RAG chunks are a derived index, not user data of record - purge outright rather than
    # leave them queryable by anything that forgets to join back to MedicalRecord.is_deleted.
    await db.execute(sa_delete(RecordChunk).where(RecordChunk.record_id == record_id))

    await db.commit()
    logger.info("Record soft-deleted (cascaded to clinical entities + RAG chunks)",
                record_id=str(record_id), user_id=str(current_user.id))


@router.get("/{record_id}/clinical", summary="Get all clinical entities extracted from a record")
async def get_record_clinical_data(record_id: uuid.UUID, current_user: CurrentUser, db: DB):
    await _verify_record_exists_or_404(db, record_id, current_user.id)
    return await _fetch_clinical_data(db, record_id, current_user.id)


async def _verify_record_exists_or_404(db: DB, record_id: uuid.UUID, user_id: uuid.UUID) -> None:
    # Existence/ownership check only - no field of the record is used here, so don't
    # hydrate the full row (extracted_text, ai_analysis, ...) like _get_record_or_404 would.
    exists = await db.scalar(
        select(MedicalRecord.id).where(
            MedicalRecord.id == record_id,
            MedicalRecord.user_id == user_id,
            MedicalRecord.is_deleted == False,  # noqa: E712
        )
    )
    if not exists:
        logger.debug("Record not found", record_id=str(record_id), user_id=str(user_id))
        raise ApiError(status_code=status.HTTP_404_NOT_FOUND, detail="Record not found", error_code=ErrorCode.RECORD_NOT_FOUND)


@router.get(
    "/{record_id}/full",
    response_model=RecordFullOut,
    summary="Get a record and all its clinical entities in a single round trip",
)
async def get_record_full(record_id: uuid.UUID, current_user: CurrentUser, db: DB):
    record = await _get_record_or_404(db, record_id, current_user.id)
    clinical = await _fetch_clinical_data(db, record_id, current_user.id)

    out = RecordFullOut.model_validate(record)
    out.download_url = await s3_service.generate_presigned_download_url(
        record.file_key, download_filename=_download_filename(record.title, record.file_mime_type)
    )
    out.clinical = RecordClinicalOut(**clinical)
    return out


async def _fetch_clinical_data(db: DB, record_id: uuid.UUID, user_id: uuid.UUID) -> dict:
    from app.models.clinical import AllergyIntolerance, Condition, Encounter, MedicationRequest, Observation
    from app.models.medication_reminder import MedicationReminder
    from app.schemas.clinical import AllergyOut, ConditionOut, EncounterOut, MedicationRequestOut, ObservationOut

    # A joinedload across these 5 sibling one-to-many collections would produce a
    # cartesian product (N conditions x M medications x ...) in a single result set -
    # wrong, not just slow. Instead, one query with 5 independent scalar subqueries,
    # each aggregated to a JSON array on the DB side. One round trip, no row blowup.
    def _agg(model):
        row = model.__table__.table_valued()
        return (
            select(func.coalesce(func.jsonb_agg(func.to_jsonb(row)), text("'[]'::jsonb")))
            .select_from(model)
            .where(
                model.user_id == user_id,
                model.source_record_id == record_id,
                model.is_deleted == False,  # noqa: E712
            )
            .scalar_subquery()
        )

    conditions, medications, observations, allergies, encounters = (await db.execute(
        select(
            _agg(Condition),
            _agg(MedicationRequest),
            _agg(Observation),
            _agg(AllergyIntolerance),
            _agg(Encounter),
        )
    )).one()

    def _parse(rows_json, out_schema, model):
        return [
            out_schema.model_validate(decrypt_jsonb_row(r, model)).model_dump(mode="json")
            for r in rows_json
        ]

    medication_dicts = _parse(medications, MedicationRequestOut, MedicationRequest)
    if medication_dicts:
        # A document-extracted medication only counts as "active" once the user has
        # turned it into an active reminder - extraction alone never implies that.
        med_ids = [uuid.UUID(m["id"]) for m in medication_dicts]
        active_reminder_med_ids = set((await db.scalars(
            select(MedicationReminder.medication_request_id).where(
                MedicationReminder.medication_request_id.in_(med_ids),
                MedicationReminder.status == "active",
                MedicationReminder.is_deleted == False,  # noqa: E712
            )
        )).all())
        for m in medication_dicts:
            m["has_active_reminder"] = uuid.UUID(m["id"]) in active_reminder_med_ids

    return {
        "conditions":   _parse(conditions, ConditionOut, Condition),
        "medications":  medication_dicts,
        "observations": _parse(observations, ObservationOut, Observation),
        "allergies":    _parse(allergies, AllergyOut, AllergyIntolerance),
        "encounters":   _parse(encounters, EncounterOut, Encounter),
    }


@router.get("/{record_id}/download", summary="Get a fresh pre-signed download URL")
async def get_download_url(record_id: uuid.UUID, current_user: CurrentUser, db: DB):
    file_key, title, mime_type = await _get_record_file_key_or_404(db, record_id, current_user.id)
    url = await s3_service.generate_presigned_download_url(
        file_key, download_filename=_download_filename(title, mime_type)
    )
    return {"download_url": url, "expires_in_seconds": settings.AWS_S3_PRESIGNED_URL_EXPIRY_SECONDS}


async def _get_record_file_key_or_404(db: DB, record_id: uuid.UUID, user_id: uuid.UUID) -> tuple[str, str, str]:
    # Only columns this endpoint needs - MedicalRecord also carries extracted_text
    # (full OCR text) and ai_analysis (JSONB), which _get_record_or_404 would
    # otherwise hydrate for no reason.
    row = (
        await db.execute(
            select(MedicalRecord.file_key, MedicalRecord.title, MedicalRecord.file_mime_type).where(
                MedicalRecord.id == record_id,
                MedicalRecord.user_id == user_id,
                MedicalRecord.is_deleted == False,  # noqa: E712
            )
        )
    ).first()
    if not row:
        logger.debug("Record not found", record_id=str(record_id), user_id=str(user_id))
        raise ApiError(status_code=status.HTTP_404_NOT_FOUND, detail="Record not found", error_code=ErrorCode.RECORD_NOT_FOUND)
    return row.file_key, row.title, row.file_mime_type


async def _get_record_or_404(db: DB, record_id: uuid.UUID, user_id: uuid.UUID) -> MedicalRecord:
    record = await db.scalar(
        select(MedicalRecord).where(
            MedicalRecord.id == record_id,
            MedicalRecord.user_id == user_id,
            MedicalRecord.is_deleted == False,  # noqa: E712
        )
    )
    if not record:
        logger.debug("Record not found", record_id=str(record_id), user_id=str(user_id))
        raise ApiError(status_code=status.HTTP_404_NOT_FOUND, detail="Record not found", error_code=ErrorCode.RECORD_NOT_FOUND)
    return record
