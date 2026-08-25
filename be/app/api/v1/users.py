import uuid
from datetime import date, datetime, timedelta, timezone

import structlog
from fastapi import APIRouter, Request, status
from sqlalchemy import select, update
from sqlalchemy.orm import selectinload

from app.core.errors import ApiError, ErrorCode
from app.dependencies import CurrentUser, DB
from app.models.auth import User, UserSession
from app.models.clinical import AllergyIntolerance, Condition
from app.models.consent import DataDeletionRequest
from app.models.profile import UserProfile
from app.utils.bmi import calculate_bmi
from app.schemas.users import (
    MeOut,
    OnboardingRequest,
    ProfileOut,
    ProfilePhotoUploadRequest,
    ProfilePhotoUploadResponse,
    ProfileUpdateRequest,
)
from app.services.s3_service import s3_service

logger = structlog.get_logger()

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/me", response_model=MeOut, summary="Get current user with profile")
async def get_me(current_user: CurrentUser, db: DB):
    user = await db.scalar(
        select(User)
        .options(selectinload(User.profile))
        .where(User.id == current_user.id)
    )
    if not user:
        raise ApiError(status_code=status.HTTP_404_NOT_FOUND, detail="User not found", error_code=ErrorCode.USER_NOT_FOUND)

    # Inject pre-signed photo URL if available
    if user.profile and user.profile.profile_photo_key:
        user.profile.profile_photo_url = await s3_service.generate_presigned_download_url(
            user.profile.profile_photo_key
        )

    return MeOut.model_validate(user)


@router.patch("/me/profile", response_model=ProfileOut, summary="Update profile fields")
async def update_profile(body: ProfileUpdateRequest, current_user: CurrentUser, db: DB):
    profile = await db.scalar(
        select(UserProfile).where(UserProfile.user_id == current_user.id)
    )
    if not profile:
        raise ApiError(status_code=status.HTTP_404_NOT_FOUND, detail="Profile not found", error_code=ErrorCode.PROFILE_NOT_FOUND)

    update_data = body.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(profile, field, value)

    # Recompute BMI if height/weight available
    h = float(profile.height_cm) if profile.height_cm else None
    w = float(profile.weight_kg) if profile.weight_kg else None
    profile.bmi = calculate_bmi(w, h)
    if profile.bmi is not None:
        logger.debug("BMI recomputed", user_id=str(current_user.id), bmi=profile.bmi)

    # Update completion percentage
    profile.profile_completion_pct = _calc_completion(profile)

    await db.commit()
    await db.refresh(profile)
    logger.info(
        "Profile updated",
        user_id=str(current_user.id),
        fields=list(update_data.keys()),
        completion_pct=profile.profile_completion_pct,
    )

    if profile.profile_photo_key:
        profile.profile_photo_url = await s3_service.generate_presigned_download_url(
            profile.profile_photo_key
        )

    return ProfileOut.model_validate(profile)


@router.post(
    "/me/profile/photo/upload-url",
    response_model=ProfilePhotoUploadResponse,
    summary="Get a pre-signed S3 upload URL for profile photo",
)
async def get_photo_upload_url(
    body: ProfilePhotoUploadRequest, current_user: CurrentUser, db: DB
):
    object_key = s3_service.generate_object_key(
        current_user.id, "profile_photos", body.filename
    )
    upload_url = await s3_service.generate_presigned_upload_url(object_key, body.content_type)

    return ProfilePhotoUploadResponse(
        upload_url=upload_url,
        object_key=object_key,
        expires_in_seconds=900,
    )


@router.post(
    "/me/profile/photo/confirm",
    response_model=ProfileOut,
    summary="Confirm profile photo upload and set the S3 key on the profile",
)
async def confirm_photo_upload(
    body: dict, current_user: CurrentUser, db: DB
):
    object_key: str = body.get("object_key", "")
    if not object_key:
        raise ApiError(status_code=status.HTTP_400_BAD_REQUEST, detail="object_key required", error_code=ErrorCode.OBJECT_KEY_REQUIRED)

    profile = await db.scalar(
        select(UserProfile).where(UserProfile.user_id == current_user.id)
    )
    if not profile:
        raise ApiError(status_code=status.HTTP_404_NOT_FOUND, detail="Profile not found", error_code=ErrorCode.PROFILE_NOT_FOUND)

    # Delete old photo if exists
    if profile.profile_photo_key and profile.profile_photo_key != object_key:
        await s3_service.delete_object(profile.profile_photo_key)

    profile.profile_photo_key = object_key
    profile.profile_photo_url = None  # Never store raw URL
    await db.commit()
    await db.refresh(profile)

    profile.profile_photo_url = await s3_service.generate_presigned_download_url(object_key)
    logger.info("Profile photo confirmed", user_id=str(current_user.id))
    return ProfileOut.model_validate(profile)


@router.delete(
    "/me",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Request account deletion - GDPR Article 17 right to erasure. "
            "Soft-deletes the account immediately and queues a 30-day purge.",
)
async def delete_me(request: Request, current_user: CurrentUser, db: DB):
    logger.info("Account deletion requested", user_id=str(current_user.id))

    # Soft-delete the user record immediately - they can no longer log in
    await db.execute(
        update(User)
        .where(User.id == current_user.id)
        .values(
            is_deleted=True,
            deleted_at=datetime.now(timezone.utc),
            is_active=False,
        )
    )

    # Revoke all active sessions
    session_result = await db.execute(
        update(UserSession)
        .where(UserSession.user_id == current_user.id, UserSession.is_active == True)  # noqa: E712
        .values(is_active=False, revoked_at=datetime.now(timezone.utc))
    )

    # Queue a data deletion request for hard purge after 30-day grace period
    purge_at = datetime.now(timezone.utc) + timedelta(days=30)
    db.add(DataDeletionRequest(
        user_id=current_user.id,
        request_type="account_deletion",
        status="pending",
        scope="all",
        requested_via="api",
        ip_address=request.client.host if request.client else None,
        requested_at=datetime.now(timezone.utc),
        response_deadline_at=purge_at,
        scheduled_purge_at=purge_at,
    ))

    await db.commit()
    logger.info(
        "Account soft-deleted, sessions revoked, purge queued",
        user_id=str(current_user.id),
        sessions_revoked=session_result.rowcount,
        scheduled_purge_at=purge_at.isoformat(),
    )


@router.post("/onboarding", summary="Complete onboarding - update health profile")
async def complete_onboarding(body: OnboardingRequest, current_user: CurrentUser, db: DB):
    profile = await db.scalar(
        select(UserProfile).where(UserProfile.user_id == current_user.id)
    )
    if not profile:
        raise ApiError(status_code=status.HTTP_404_NOT_FOUND, detail="Profile not found", error_code=ErrorCode.PROFILE_NOT_FOUND)

    if body.full_name is not None:
        profile.full_name = body.full_name
    if body.year_of_birth is not None:
        profile.date_of_birth = date(body.year_of_birth, 1, 1)
    if body.gender is not None:
        profile.gender = body.gender
    if body.height_cm is not None:
        profile.height_cm = body.height_cm
    if body.weight_kg is not None:
        profile.weight_kg = body.weight_kg
    if body.blood_group is not None:
        profile.blood_group = body.blood_group

    h = float(profile.height_cm) if profile.height_cm else None
    w = float(profile.weight_kg) if profile.weight_kg else None
    profile.bmi = calculate_bmi(w, h)

    profile.profile_completion_pct = _calc_completion(profile)

    # ── Persist conditions ────────────────────────────────────────────────────
    if body.existing_conditions:
        existing_condition_names = {
            n.lower() for n in (await db.scalars(
                select(Condition.condition_name).where(
                    Condition.user_id == current_user.id,
                    Condition.is_deleted == False,  # noqa: E712
                )
            )).all()
        }
        for raw in body.existing_conditions:
            name = raw.strip()
            if name and name.lower() not in existing_condition_names:
                db.add(Condition(
                    user_id=current_user.id,
                    condition_name=name,
                    clinical_status="active",
                    verification_status="unconfirmed",
                    source="patient_reported",
                ))
                existing_condition_names.add(name.lower())

    # ── Persist allergies ─────────────────────────────────────────────────────
    if body.allergies:
        # Support comma-separated ("Penicillin, Aspirin") or single name
        allergy_names = [a.strip() for a in body.allergies.split(",") if a.strip()]
        existing_allergy_names = {
            n.lower() for n in (await db.scalars(
                select(AllergyIntolerance.substance_name).where(
                    AllergyIntolerance.user_id == current_user.id,
                    AllergyIntolerance.is_deleted == False,  # noqa: E712
                )
            )).all()
        }
        for name in allergy_names:
            if name.lower() not in existing_allergy_names:
                db.add(AllergyIntolerance(
                    user_id=current_user.id,
                    substance_name=name,
                    clinical_status="active",
                    verification_status="unconfirmed",
                    source="patient_reported",
                ))
                existing_allergy_names.add(name.lower())

    await db.commit()
    logger.info("Onboarding completed", user_id=str(current_user.id), completion_pct=profile.profile_completion_pct)
    return {"message": "Profile updated successfully"}


def _calc_completion(profile: UserProfile) -> int:
    fields = [
        profile.full_name,
        profile.date_of_birth,
        profile.gender,
        profile.blood_group,
        profile.height_cm,
        profile.weight_kg,
        profile.profile_photo_key,
    ]
    filled = sum(1 for f in fields if f is not None)
    return int((filled / len(fields)) * 100)
