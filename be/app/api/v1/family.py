import uuid
from datetime import date, datetime, timezone

import structlog
from fastapi import APIRouter, status
from sqlalchemy import delete as sa_delete, select, update as sa_update

from app.core.errors import ApiError, ErrorCode
from app.dependencies import CurrentUser, DB
from app.models.clinical import AllergyIntolerance, Condition, Encounter, MedicationRequest, Observation
from app.models.family import FamilyMember
from app.models.records import MedicalRecord, RecordChunk
from app.schemas.family import (
    FamilyMemberCreateRequest,
    FamilyMemberOut,
    FamilyMemberPhotoUploadResponse,
    FamilyMemberUpdateRequest,
)
from app.services.s3_service import s3_service

logger = structlog.get_logger()

router = APIRouter(prefix="/family", tags=["family"])


def _calc_age(dob: date | None) -> int | None:
    if not dob:
        return None
    from datetime import date as today_date
    today = today_date.today()
    return today.year - dob.year - ((today.month, today.day) < (dob.month, dob.day))


async def _get_member_or_404(db: DB, member_id: uuid.UUID, owner_id: uuid.UUID) -> FamilyMember:
    member = await db.scalar(
        select(FamilyMember).where(
            FamilyMember.id == member_id,
            FamilyMember.owner_user_id == owner_id,
            FamilyMember.is_deleted == False,  # noqa: E712
        )
    )
    if not member:
        logger.debug("Family member not found", member_id=str(member_id), owner_id=str(owner_id))
        raise ApiError(status_code=status.HTTP_404_NOT_FOUND, detail="Family member not found", error_code=ErrorCode.FAMILY_MEMBER_NOT_FOUND)
    return member


async def _inject_photo_url(member: FamilyMember) -> None:
    if member.photo_key:
        member.photo_url = await s3_service.generate_presigned_download_url(member.photo_key)


@router.get("", response_model=list[FamilyMemberOut], summary="List family members")
async def list_family_members(current_user: CurrentUser, db: DB):
    members = (await db.scalars(
        select(FamilyMember).where(
            FamilyMember.owner_user_id == current_user.id,
            FamilyMember.is_deleted == False,  # noqa: E712
        ).order_by(FamilyMember.created_at.asc())
    )).all()

    for m in members:
        m.age = _calc_age(m.date_of_birth)
        await _inject_photo_url(m)

    return [FamilyMemberOut.model_validate(m) for m in members]


@router.post("", response_model=FamilyMemberOut, status_code=status.HTTP_201_CREATED)
async def create_family_member(
    body: FamilyMemberCreateRequest, current_user: CurrentUser, db: DB
):
    member = FamilyMember(
        owner_user_id=current_user.id,
        full_name=body.full_name,
        relationship=body.relationship,
        role=body.role,
        access_level=body.access_level,
        date_of_birth=body.date_of_birth,
        age=_calc_age(body.date_of_birth),
        gender=body.gender,
        blood_group=body.blood_group,
    )
    db.add(member)
    await db.commit()
    await db.refresh(member)
    logger.info("Family member created", member_id=str(member.id), owner_id=str(current_user.id))
    return FamilyMemberOut.model_validate(member)


@router.get("/{member_id}", response_model=FamilyMemberOut)
async def get_family_member(member_id: uuid.UUID, current_user: CurrentUser, db: DB):
    member = await _get_member_or_404(db, member_id, current_user.id)
    member.age = _calc_age(member.date_of_birth)
    await _inject_photo_url(member)
    return FamilyMemberOut.model_validate(member)


@router.patch("/{member_id}", response_model=FamilyMemberOut)
async def update_family_member(
    member_id: uuid.UUID, body: FamilyMemberUpdateRequest, current_user: CurrentUser, db: DB
):
    member = await _get_member_or_404(db, member_id, current_user.id)

    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(member, field, value)

    member.age = _calc_age(member.date_of_birth)
    await db.commit()
    await db.refresh(member)
    await _inject_photo_url(member)
    logger.info("Family member updated", member_id=str(member_id))
    return FamilyMemberOut.model_validate(member)


@router.delete("/{member_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_family_member(member_id: uuid.UUID, current_user: CurrentUser, db: DB):
    member = await _get_member_or_404(db, member_id, current_user.id)
    now = datetime.now(timezone.utc)

    member.is_deleted = True
    member.deleted_at = now
    member.deleted_by_id = current_user.id

    # The UI tells the user this removes "their health records" too, so make that true:
    # cascade the same soft-delete records.delete_record does, scoped to this family member,
    # instead of leaving their records/clinical data behind as orphaned-but-still-fetchable rows.
    record_ids = (await db.scalars(
        select(MedicalRecord.id).where(
            MedicalRecord.user_id == current_user.id,
            MedicalRecord.family_member_id == member_id,
            MedicalRecord.is_deleted == False,  # noqa: E712
        )
    )).all()

    if record_ids:
        await db.execute(
            sa_update(MedicalRecord)
            .where(MedicalRecord.id.in_(record_ids))
            .values(is_deleted=True, deleted_at=now, deleted_by_id=current_user.id, deletion_type="family_removed")
        )
        for model in (Condition, MedicationRequest, Observation, AllergyIntolerance, Encounter):
            await db.execute(
                sa_update(model)
                .where(
                    model.user_id == current_user.id,
                    model.source_record_id.in_(record_ids),
                    model.is_deleted == False,  # noqa: E712
                )
                .values(is_deleted=True, deleted_at=now, deleted_by_id=current_user.id)
            )
        await db.execute(sa_delete(RecordChunk).where(RecordChunk.record_id.in_(record_ids)))

    await db.commit()
    logger.info(
        "Family member soft-deleted (cascaded to their records + clinical entities)",
        member_id=str(member_id), records_deleted=len(record_ids),
    )


@router.post(
    "/{member_id}/photo/upload-url",
    response_model=FamilyMemberPhotoUploadResponse,
)
async def get_family_photo_upload_url(
    member_id: uuid.UUID,
    body: dict,
    current_user: CurrentUser,
    db: DB,
):
    await _get_member_or_404(db, member_id, current_user.id)
    filename = body.get("filename", "photo.jpg")
    content_type = body.get("content_type", "image/jpeg")

    if content_type not in ("image/jpeg", "image/png", "image/webp"):
        raise ApiError(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid image type", error_code=ErrorCode.INVALID_IMAGE_TYPE)

    object_key = s3_service.generate_object_key(current_user.id, f"family/{member_id}", filename)
    upload_url = await s3_service.generate_presigned_upload_url(object_key, content_type)

    return FamilyMemberPhotoUploadResponse(
        upload_url=upload_url,
        object_key=object_key,
        expires_in_seconds=900,
    )


@router.post("/{member_id}/photo/confirm", response_model=FamilyMemberOut)
async def confirm_family_photo(
    member_id: uuid.UUID, body: dict, current_user: CurrentUser, db: DB
):
    member = await _get_member_or_404(db, member_id, current_user.id)
    object_key: str = body.get("object_key", "")
    if not object_key:
        raise ApiError(status_code=status.HTTP_400_BAD_REQUEST, detail="object_key required", error_code=ErrorCode.OBJECT_KEY_REQUIRED)

    if member.photo_key and member.photo_key != object_key:
        await s3_service.delete_object(member.photo_key)

    member.photo_key = object_key
    member.photo_url = None
    await db.commit()
    await db.refresh(member)

    member.age = _calc_age(member.date_of_birth)
    member.photo_url = await s3_service.generate_presigned_download_url(object_key)
    logger.info("Family member photo confirmed", member_id=str(member_id))
    return FamilyMemberOut.model_validate(member)
