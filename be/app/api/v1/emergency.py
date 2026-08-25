import re
import uuid
from datetime import datetime, timezone

import structlog
from fastapi import APIRouter, status
from pydantic import BaseModel, ConfigDict, Field, field_validator
from sqlalchemy import select

from app.core.errors import ApiError, ErrorCode
from app.core.scoping import family_scope, validate_family_member_ownership
from app.dependencies import CurrentUser, DB
from app.models.emergency import EmergencyContact, EmergencySetting

logger = structlog.get_logger()

router = APIRouter(prefix="/emergency", tags=["emergency"])

_PHONE_RE = re.compile(r"^\+[1-9]\d{6,14}$")


class EmergencySettingOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    user_id: uuid.UUID
    family_member_id: uuid.UUID | None
    lock_screen_widget_enabled: bool
    show_blood_group: bool
    show_allergies: bool
    show_emergency_contacts: bool
    show_chronic_conditions: bool
    updated_at: datetime


class EmergencySettingUpdateRequest(BaseModel):
    family_member_id: uuid.UUID | None = None
    lock_screen_widget_enabled: bool | None = None
    show_blood_group: bool | None = None
    show_allergies: bool | None = None
    show_emergency_contacts: bool | None = None
    show_chronic_conditions: bool | None = None


class EmergencyContactCreateRequest(BaseModel):
    family_member_id: uuid.UUID | None = None
    full_name: str = Field(..., min_length=1, max_length=255)
    relationship: str | None = Field(None, max_length=100)
    phone_number: str
    is_primary: bool = False
    sort_order: int = 0

    @field_validator("phone_number")
    @classmethod
    def validate_phone(cls, v: str) -> str:
        if not _PHONE_RE.match(v):
            raise ValueError("Phone must be E.164 format, e.g. +923001234567")
        return v


class EmergencyContactOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    user_id: uuid.UUID
    family_member_id: uuid.UUID | None
    full_name: str
    relationship: str | None
    phone_number: str
    is_primary: bool
    sort_order: int
    created_at: datetime
    updated_at: datetime


@router.get("/settings", response_model=EmergencySettingOut)
async def get_emergency_settings(
    current_user: CurrentUser, db: DB, family_member_id: uuid.UUID | None = None
):
    setting = await _get_or_create_settings(db, current_user.id, family_member_id)
    return EmergencySettingOut.model_validate(setting)


@router.patch("/settings", response_model=EmergencySettingOut)
async def update_emergency_settings(
    body: EmergencySettingUpdateRequest, current_user: CurrentUser, db: DB
):
    setting = await _get_or_create_settings(db, current_user.id, body.family_member_id)
    for k, v in body.model_dump(exclude_unset=True, exclude={"family_member_id"}).items():
        setattr(setting, k, v)
    setting.updated_by_id = current_user.id
    await db.commit()
    await db.refresh(setting)
    logger.info("Emergency settings updated", user_id=str(current_user.id))
    return EmergencySettingOut.model_validate(setting)


@router.get("/contacts", response_model=list[EmergencyContactOut])
async def list_contacts(
    current_user: CurrentUser, db: DB, family_member_id: uuid.UUID | None = None
):
    contacts = (await db.scalars(
        select(EmergencyContact).where(
            EmergencyContact.user_id == current_user.id,
            EmergencyContact.is_deleted == False,  # noqa: E712
            family_scope(EmergencyContact, family_member_id),
        ).order_by(EmergencyContact.sort_order.asc(), EmergencyContact.created_at.asc())
    )).all()
    return [EmergencyContactOut.model_validate(c) for c in contacts]


@router.post("/contacts", response_model=EmergencyContactOut, status_code=status.HTTP_201_CREATED)
async def create_contact(body: EmergencyContactCreateRequest, current_user: CurrentUser, db: DB):
    await validate_family_member_ownership(db, current_user.id, body.family_member_id)
    contact = EmergencyContact(
        user_id=current_user.id,
        family_member_id=body.family_member_id,
        full_name=body.full_name,
        relationship=body.relationship,
        phone_number=body.phone_number,
        is_primary=body.is_primary,
        sort_order=body.sort_order,
    )
    db.add(contact)
    await db.commit()
    await db.refresh(contact)
    logger.info("Emergency contact created", contact_id=str(contact.id), user_id=str(current_user.id))
    return EmergencyContactOut.model_validate(contact)


@router.delete("/contacts/{contact_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_contact(contact_id: uuid.UUID, current_user: CurrentUser, db: DB):
    contact = await db.scalar(
        select(EmergencyContact).where(
            EmergencyContact.id == contact_id,
            EmergencyContact.user_id == current_user.id,
            EmergencyContact.is_deleted == False,  # noqa: E712
        )
    )
    if not contact:
        logger.debug("Emergency contact not found", contact_id=str(contact_id), user_id=str(current_user.id))
        raise ApiError(status_code=status.HTTP_404_NOT_FOUND, detail="Contact not found", error_code=ErrorCode.EMERGENCY_CONTACT_NOT_FOUND)
    contact.is_deleted = True
    contact.deleted_at = datetime.now(timezone.utc)
    contact.deleted_by_id = current_user.id
    await db.commit()
    logger.info("Emergency contact deleted", contact_id=str(contact_id), user_id=str(current_user.id))


async def _get_or_create_settings(
    db, user_id: uuid.UUID, family_member_id: uuid.UUID | None
) -> EmergencySetting:
    setting = await db.scalar(
        select(EmergencySetting).where(
            EmergencySetting.user_id == user_id,
            family_scope(EmergencySetting, family_member_id),
        )
    )
    if not setting:
        await validate_family_member_ownership(db, user_id, family_member_id)
        setting = EmergencySetting(user_id=user_id, family_member_id=family_member_id)
        db.add(setting)
        await db.commit()
        await db.refresh(setting)
    return setting
