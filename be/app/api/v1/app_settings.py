import uuid
from datetime import datetime

import structlog
from fastapi import APIRouter
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import func
from sqlalchemy.dialects.postgresql import insert as pg_insert

from app.core.enums import Language
from app.dependencies import CurrentUser, DB
from app.models.settings import AppSetting

logger = structlog.get_logger()

router = APIRouter(prefix="/settings", tags=["settings"])


class AppSettingOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    user_id: uuid.UUID
    language: Language
    theme: str
    biometric_lock_enabled: bool
    push_notifications_enabled: bool
    email_notifications_enabled: bool
    drug_interaction_alerts: bool
    lab_result_alerts: bool
    vital_threshold_alerts: bool
    analytics_opt_in: bool
    updated_at: datetime


class AppSettingUpdateRequest(BaseModel):
    language: Language | None = None
    theme: str | None = Field(None, pattern="^(dark|light)$")
    biometric_lock_enabled: bool | None = None
    push_notifications_enabled: bool | None = None
    email_notifications_enabled: bool | None = None
    drug_interaction_alerts: bool | None = None
    lab_result_alerts: bool | None = None
    vital_threshold_alerts: bool | None = None
    analytics_opt_in: bool | None = None


@router.get("", response_model=AppSettingOut)
async def get_settings(current_user: CurrentUser, db: DB):
    setting = await _upsert_settings(db, current_user.id, {})
    return AppSettingOut.model_validate(setting)


@router.patch("", response_model=AppSettingOut)
async def update_settings(body: AppSettingUpdateRequest, current_user: CurrentUser, db: DB):
    changed = body.model_dump(exclude_unset=True)
    setting = await _upsert_settings(db, current_user.id, changed)
    logger.info("App settings updated", user_id=str(current_user.id), fields=list(changed.keys()))
    return AppSettingOut.model_validate(setting)


async def _upsert_settings(db: DB, user_id: uuid.UUID, changed: dict) -> AppSetting:
    """
    Atomic get-or-create-or-update via INSERT ... ON CONFLICT DO UPDATE - replaces the old
    SELECT-then-INSERT, which had a race window (two concurrent first-time requests could both
    miss the SELECT and both INSERT, and the loser would hit the user_id unique constraint).
    """
    stmt = pg_insert(AppSetting).values(user_id=user_id, **changed)
    if changed:
        # Real update: bump updated_at same as the onupdate= trigger did before (that trigger
        # is ORM-flush-only and doesn't fire for a raw INSERT..ON CONFLICT statement).
        set_ = {**changed, "updated_at": func.now()}
    else:
        # Nothing to change (plain GET) - no-op self-assignment, just to make ON CONFLICT DO
        # UPDATE ... RETURNING hand back the existing row (DO NOTHING returns no rows).
        set_ = {"user_id": stmt.excluded.user_id}
    stmt = stmt.on_conflict_do_update(index_elements=[AppSetting.user_id], set_=set_).returning(AppSetting)

    setting = (await db.execute(stmt)).scalar_one()
    await db.commit()
    return setting
