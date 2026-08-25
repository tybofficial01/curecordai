import uuid
from datetime import datetime, timezone

import structlog
from fastapi import status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from app.core.errors import ApiError, ErrorCode
from app.models.auth import User
from app.models.clinical import AllergyIntolerance, Condition
from app.models.sharing import DataSharingConsent
from app.services.s3_service import s3_service
from app.utils.bmi import calculate_bmi

logger = structlog.get_logger()



async def get_full_profile(user_id: uuid.UUID, db: AsyncSession) -> dict:
    # Single query: User + UserProfile + AppSetting via JOIN (both are 1-to-1, so joining
    # them together can't multiply rows the way it would for a to-many relationship).
    user = await db.scalar(
        select(User)
        .options(joinedload(User.profile), joinedload(User.setting))
        .where(User.id == user_id)
    )
    if not user:
        raise ApiError(status_code=status.HTTP_404_NOT_FOUND, detail="User not found", error_code=ErrorCode.USER_NOT_FOUND)

    profile = user.profile
    setting = user.setting

    allergies = (
        await db.scalars(
            select(AllergyIntolerance).where(
                AllergyIntolerance.user_id == user_id,
                AllergyIntolerance.is_deleted == False,  # noqa: E712
                AllergyIntolerance.family_member_id == None,  # noqa: E711
            )
        )
    ).all()
    conditions = (
        await db.scalars(
            select(Condition).where(
                Condition.user_id == user_id,
                Condition.is_deleted == False,  # noqa: E712
                Condition.family_member_id == None,  # noqa: E711
            )
        )
    ).all()

    h = float(profile.height_cm) if profile and profile.height_cm else None
    w = float(profile.weight_kg) if profile and profile.weight_kg else None
    bmi = calculate_bmi(w, h)

    avatar_url = None
    if profile and profile.profile_photo_key:
        avatar_url = await s3_service.generate_presigned_download_url(profile.profile_photo_key)

    allergies_str = ", ".join(a.substance_name for a in allergies) if allergies else None

    return {
        "patient_id_display": profile.patient_id_display if profile else None,
        "profile_photo_url": avatar_url,
        "full_name": profile.full_name if profile else "",
        "date_of_birth": profile.date_of_birth if profile else None,
        "gender": profile.gender if profile else None,
        "phone_number": user.phone_number,
        "height_cm": h,
        "weight_kg": w,
        "blood_group": profile.blood_group if profile else None,
        "bmi": bmi,
        "language": setting.language if setting else "en",
        "theme": setting.theme if setting else "dark",
        "biometric_lock": setting.biometric_lock_enabled if setting else False,
        "allergies": allergies_str,
        "conditions": [c.condition_name for c in conditions],
        "profile_completion_pct": profile.profile_completion_pct if profile else 0,
    }


async def validate_sharing_ownership(
    sharing_id: uuid.UUID, user_id: uuid.UUID, db: AsyncSession
) -> DataSharingConsent:
    record = await db.get(DataSharingConsent, sharing_id)
    if not record:
        raise ApiError(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Sharing record not found",
            error_code=ErrorCode.SHARING_RECORD_NOT_FOUND,
        )
    if record.user_id != user_id:
        raise ApiError(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied", error_code=ErrorCode.ACCESS_DENIED)
    return record
