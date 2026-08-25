import os
import uuid
from datetime import datetime, timezone

import structlog
from fastapi import APIRouter, File, UploadFile, status
from sqlalchemy import insert as sa_insert, select

from app.config import settings as app_settings
from app.core.errors import ApiError, ErrorCode
from app.dependencies import CurrentUser, DB
from app.models.auth import User
from app.services.s3_service import s3_service
from app.models.clinical import AllergyIntolerance, Condition
from app.models.profile import UserProfile
from app.models.settings import AppSetting
from app.models.sharing import DataSharingConsent
from app.utils.bmi import calculate_bmi
from app.schemas.profile import (
    DataSharingResponse,
    DataSharingSchema,
    FullProfileResponse,
    HealthDetailsSchema,
    PhysicalMetricsResponse,
    PhysicalMetricsSchema,
    PreferencesSchema,
    PrivacySchema,
    ProfileInfoSchema,
)
from app.services.profile_service import (
    get_full_profile,
    validate_sharing_ownership,
)

logger = structlog.get_logger()

router = APIRouter(prefix="/profile", tags=["Profile"])

_ALLOWED_AVATAR_TYPES = {"image/jpeg", "image/png", "image/webp"}
_MAX_AVATAR_BYTES = 5 * 1024 * 1024  # 5 MB


def _recalc_completion(profile: UserProfile) -> int:
    fields = [
        profile.full_name, profile.date_of_birth, profile.gender,
        profile.blood_group, profile.height_cm, profile.weight_kg, profile.profile_photo_key,
    ]
    return int(sum(1 for f in fields if f is not None) / len(fields) * 100)


# ── 1. GET /profile ───────────────────────────────────────────────────────────

@router.get("", response_model=FullProfileResponse)
async def get_profile(current_user: CurrentUser, db: DB):
    data = await get_full_profile(current_user.id, db)
    return FullProfileResponse(**data)


# ── 2. PUT /profile ───────────────────────────────────────────────────────────

@router.put("", response_model=FullProfileResponse)
async def update_profile_info(body: ProfileInfoSchema, current_user: CurrentUser, db: DB):
    profile = await db.scalar(select(UserProfile).where(UserProfile.user_id == current_user.id))
    if not profile:
        raise ApiError(status_code=status.HTTP_404_NOT_FOUND, detail="Profile not found", error_code=ErrorCode.PROFILE_NOT_FOUND)

    profile.full_name = body.full_name
    profile.date_of_birth = body.date_of_birth
    if body.gender:
        normalised = body.gender.lower().replace(" ", "_")
        profile.gender = "unknown" if normalised in ("prefer_not_to_say", "other") else normalised
    else:
        profile.gender = None

    user = await db.get(User, current_user.id)
    if user:
        user.phone_number = body.phone_number

    profile.profile_completion_pct = _recalc_completion(profile)

    # Snapshot fields before commit expires the ORM objects
    patient_id = profile.patient_id_display
    photo_key = profile.profile_photo_key
    saved_gender = profile.gender
    saved_phone = user.phone_number if user else None
    h = float(profile.height_cm) if profile.height_cm else None
    w = float(profile.weight_kg) if profile.weight_kg else None
    bmi = calculate_bmi(w, h)
    blood_group = profile.blood_group
    completion_pct = profile.profile_completion_pct

    await db.commit()

    logger.info("profile.info.updated", user_id=str(current_user.id), ts=datetime.now(timezone.utc).isoformat())

    avatar_url = None
    if photo_key:
        avatar_url = await s3_service.generate_presigned_download_url(photo_key)

    # Load only the data not already in memory (3 queries instead of re-running get_full_profile)
    setting = await db.scalar(select(AppSetting).where(AppSetting.user_id == current_user.id))
    allergies = (await db.scalars(
        select(AllergyIntolerance).where(
            AllergyIntolerance.user_id == current_user.id,
            AllergyIntolerance.is_deleted == False,  # noqa: E712
            AllergyIntolerance.family_member_id == None,  # noqa: E711
        )
    )).all()
    conditions = (await db.scalars(
        select(Condition).where(
            Condition.user_id == current_user.id,
            Condition.is_deleted == False,  # noqa: E712
            Condition.family_member_id == None,  # noqa: E711
        )
    )).all()

    return FullProfileResponse(
        patient_id_display=patient_id,
        profile_photo_url=avatar_url,
        full_name=body.full_name,
        date_of_birth=body.date_of_birth,
        gender=saved_gender,
        phone_number=saved_phone,
        height_cm=h,
        weight_kg=w,
        blood_group=blood_group,
        bmi=bmi,
        language=setting.language if setting else "en",
        theme=setting.theme if setting else "light",
        biometric_lock=setting.biometric_lock_enabled if setting else False,
        allergies=", ".join(a.substance_name for a in allergies) if allergies else None,
        conditions=[c.condition_name for c in conditions],
        profile_completion_pct=completion_pct,
    )


# ── 3. PUT /profile/physical-metrics ─────────────────────────────────────────

@router.put("/physical-metrics", response_model=PhysicalMetricsResponse)
async def update_physical_metrics(body: PhysicalMetricsSchema, current_user: CurrentUser, db: DB):
    profile = await db.scalar(select(UserProfile).where(UserProfile.user_id == current_user.id))
    if not profile:
        raise ApiError(status_code=status.HTTP_404_NOT_FOUND, detail="Profile not found", error_code=ErrorCode.PROFILE_NOT_FOUND)

    if body.height_cm is not None:
        profile.height_cm = body.height_cm
    if body.weight_kg is not None:
        profile.weight_kg = body.weight_kg
    if body.blood_group is not None:
        profile.blood_group = body.blood_group

    h = float(profile.height_cm) if profile.height_cm is not None else None
    w = float(profile.weight_kg) if profile.weight_kg is not None else None
    profile.bmi = calculate_bmi(w, h)

    profile.profile_completion_pct = _recalc_completion(profile)

    await db.commit()

    logger.info("profile.physical.updated", user_id=str(current_user.id), ts=datetime.now(timezone.utc).isoformat())

    return PhysicalMetricsResponse(bmi=profile.bmi, message="Physical metrics updated")


# ── 4. PUT /profile/health-details ───────────────────────────────────────────

@router.put("/health-details")
async def update_health_details(body: HealthDetailsSchema, current_user: CurrentUser, db: DB):
    now = datetime.now(timezone.utc)

    # Soft-delete existing patient-reported allergies
    existing_allergies = (
        await db.scalars(
            select(AllergyIntolerance).where(
                AllergyIntolerance.user_id == current_user.id,
                AllergyIntolerance.is_deleted == False,  # noqa: E712
                AllergyIntolerance.family_member_id == None,  # noqa: E711
                AllergyIntolerance.source == "patient_reported",
            )
        )
    ).all()
    for a in existing_allergies:
        a.is_deleted = True
        a.deleted_at = now
        a.deleted_by_id = current_user.id

    # Soft-delete existing patient-reported conditions
    existing_conditions = (
        await db.scalars(
            select(Condition).where(
                Condition.user_id == current_user.id,
                Condition.is_deleted == False,  # noqa: E712
                Condition.family_member_id == None,  # noqa: E711
                Condition.source == "patient_reported",
            )
        )
    ).all()
    for c in existing_conditions:
        c.is_deleted = True
        c.deleted_at = now
        c.deleted_by_id = current_user.id

    # Bulk-insert new allergies - single INSERT regardless of N
    allergy_names = [s.strip() for s in body.allergies.split(",") if s.strip()]
    if allergy_names:
        await db.execute(
            sa_insert(AllergyIntolerance),
            [{"user_id": current_user.id, "substance_name": s, "source": "patient_reported"}
             for s in allergy_names],
        )

    # Bulk-insert new conditions - single INSERT regardless of M
    if body.conditions:
        await db.execute(
            sa_insert(Condition),
            [{"user_id": current_user.id, "condition_name": c.strip(), "source": "patient_reported"}
             for c in body.conditions],
        )

    await db.commit()

    logger.info("profile.health.updated", user_id=str(current_user.id), ts=now.isoformat())

    return {"data": None, "message": "Health details updated"}


# ── 6. PUT /profile/preferences ───────────────────────────────────────────────

@router.put("/preferences")
async def update_preferences(body: PreferencesSchema, current_user: CurrentUser, db: DB):
    setting = await _get_or_create_setting(db, current_user.id)
    setting.language = body.language
    setting.theme = "dark" if body.is_dark_theme else "light"
    await db.commit()

    logger.info("profile.preferences.updated", user_id=str(current_user.id), ts=datetime.now(timezone.utc).isoformat())

    return {"data": None, "message": "Preferences saved"}


# ── 6b. GET /profile/preferences ─────────────────────────────────────────────

@router.get("/preferences")
async def get_preferences(current_user: CurrentUser, db: DB):
    setting = await _get_or_create_setting(db, current_user.id)
    return {
        "language": setting.language,
        "is_dark_theme": setting.theme == "dark",
    }


# ── 7a. GET /profile/privacy ──────────────────────────────────────────────────

@router.get("/privacy")
async def get_privacy(current_user: CurrentUser, db: DB):
    setting = await _get_or_create_setting(db, current_user.id)
    return {
        "biometric_lock": setting.biometric_lock_enabled,
        "app_lock_on_background": setting.app_lock_on_background,
        "screenshot_prevention": setting.screenshot_prevention,
    }


# ── 7b. PUT /profile/privacy ──────────────────────────────────────────────────

@router.put("/privacy")
async def update_privacy(body: PrivacySchema, current_user: CurrentUser, db: DB):
    setting = await _get_or_create_setting(db, current_user.id)
    setting.biometric_lock_enabled = body.biometric_lock
    setting.app_lock_on_background = body.app_lock_on_background
    setting.screenshot_prevention = body.screenshot_prevention
    await db.commit()

    logger.info("profile.privacy.updated", user_id=str(current_user.id), ts=datetime.now(timezone.utc).isoformat())

    return {"data": None, "message": "Privacy settings updated"}


# ── 8. GET /profile/data-sharing ──────────────────────────────────────────────

@router.get("/data-sharing", response_model=list[DataSharingResponse])
async def list_data_sharing(current_user: CurrentUser, db: DB):
    records = (
        await db.scalars(
            select(DataSharingConsent).where(
                DataSharingConsent.user_id == current_user.id,
                DataSharingConsent.status != "revoked",
            )
        )
    ).all()

    return [
        DataSharingResponse(
            id=r.id,
            name=r.grantee_name or "",
            access_type=r.access_scope,
            granted_until=r.expires_at.date() if r.expires_at else None,
            status=r.status,
            created_at=r.created_at,
        )
        for r in records
    ]


# ── 9. POST /profile/data-sharing ─────────────────────────────────────────────

@router.post("/data-sharing", response_model=DataSharingResponse, status_code=status.HTTP_201_CREATED)
async def create_data_sharing(body: DataSharingSchema, current_user: CurrentUser, db: DB):
    expires_at = None
    if body.granted_until:
        expires_at = datetime.combine(body.granted_until, datetime.min.time()).replace(tzinfo=timezone.utc)

    record = DataSharingConsent(
        user_id=current_user.id,
        grantee_name=body.name,
        grantee_type="individual",
        access_scope=body.access_type,
        expires_at=expires_at,
        status="active",
    )
    db.add(record)
    await db.commit()
    await db.refresh(record)

    logger.info("profile.sharing.created", user_id=str(current_user.id), sharing_id=str(record.id), ts=datetime.now(timezone.utc).isoformat())

    return DataSharingResponse(
        id=record.id,
        name=record.grantee_name or "",
        access_type=record.access_scope,
        granted_until=record.expires_at.date() if record.expires_at else None,
        status=record.status,
        created_at=record.created_at,
    )


# ── 10. DELETE /profile/data-sharing/{sharing_id} ────────────────────────────

@router.delete("/data-sharing/{sharing_id}")
async def delete_data_sharing(sharing_id: uuid.UUID, current_user: CurrentUser, db: DB):
    record = await validate_sharing_ownership(sharing_id, current_user.id, db)
    record.status = "revoked"
    record.revoked_at = datetime.now(timezone.utc)
    await db.commit()

    logger.info("profile.sharing.revoked", user_id=str(current_user.id), sharing_id=str(sharing_id), ts=datetime.now(timezone.utc).isoformat())

    return {"message": "Access revoked"}


# ── 11. POST /profile/avatar ──────────────────────────────────────────────────

@router.post("/avatar")
async def upload_avatar(
    current_user: CurrentUser,
    db: DB,
    file: UploadFile = File(...),
):
    if file.content_type not in _ALLOWED_AVATAR_TYPES:
        raise ApiError(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Only JPEG, PNG, or WebP images are allowed",
            error_code=ErrorCode.INVALID_AVATAR_TYPE,
        )

    contents = await file.read()
    if len(contents) > _MAX_AVATAR_BYTES:
        raise ApiError(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="Avatar file must be under 5 MB",
            error_code=ErrorCode.AVATAR_TOO_LARGE,
        )

    profile = await db.scalar(select(UserProfile).where(UserProfile.user_id == current_user.id))
    if not profile:
        raise ApiError(status_code=status.HTTP_404_NOT_FOUND, detail="Profile not found", error_code=ErrorCode.PROFILE_NOT_FOUND)

    ext = file.content_type.split("/")[-1].replace("jpeg", "jpg")
    filename = f"{current_user.id}_{uuid.uuid4()}.{ext}"

    try:
        if app_settings.AWS_ACCESS_KEY_ID:
            key = f"users/{current_user.id}/avatars/{filename}"
            s3_service.client.put_object(
                Bucket=app_settings.AWS_S3_BUCKET_NAME,
                Key=key,
                Body=contents,
                ContentType=file.content_type,
            )
            avatar_url = await s3_service.generate_presigned_download_url(key)
        else:
            # Local fallback
            media_dir = os.path.join(os.getcwd(), "media", "avatars")
            os.makedirs(media_dir, exist_ok=True)
            local_path = os.path.join(media_dir, filename)
            with open(local_path, "wb") as f:
                f.write(contents)
            key = f"media/avatars/{filename}"
            avatar_url = f"/media/avatars/{filename}"

        profile.profile_photo_key = key
        profile.profile_photo_url = None  # never store raw URL; generate on demand
        await db.commit()

        logger.info("profile.avatar.updated", user_id=str(current_user.id), key=key, ts=datetime.now(timezone.utc).isoformat())

        return {"avatar_url": avatar_url}

    except Exception as exc:
        logger.error("profile.avatar.upload_failed", user_id=str(current_user.id), error=str(exc))
        raise ApiError(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Avatar upload failed", error_code=ErrorCode.AVATAR_UPLOAD_FAILED)


# ── helpers ───────────────────────────────────────────────────────────────────

async def _get_or_create_setting(db, user_id: uuid.UUID) -> AppSetting:
    setting = await db.scalar(select(AppSetting).where(AppSetting.user_id == user_id))
    if not setting:
        setting = AppSetting(user_id=user_id)
        db.add(setting)
        await db.flush()
    return setting
