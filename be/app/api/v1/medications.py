"""
Medication management & reminder APIs. Reminders can be created from an already-extracted
MedicationRequest (source='document') or typed manually (source='manual'); either way they're
scoped to the owner or one specific family member via the shared family_scope/ownership rules.
"""
import uuid
from datetime import date, datetime, timedelta, timezone as dt_timezone

import structlog
from fastapi import APIRouter, Query, status
from sqlalchemy import select

from app.core.errors import ApiError, ErrorCode
from app.core.scoping import family_scope, validate_family_member_ownership
from app.dependencies import CurrentUser, DB
from app.models.clinical import MedicationRequest
from app.models.medication_reminder import MedicationDoseLog, MedicationReminder
from app.schemas.medications import (
    DoseLogOut,
    DoseStatusUpdateRequest,
    MedicationReminderCreateRequest,
    MedicationReminderOut,
    MedicationReminderUpdateRequest,
    UpcomingDoseOut,
)
from app.services.medication_schedule import occurrences_between

logger = structlog.get_logger()

router = APIRouter(prefix="/medications", tags=["medications"])


async def _get_reminder_or_404(db: DB, reminder_id: uuid.UUID, user_id: uuid.UUID) -> MedicationReminder:
    reminder = await db.scalar(
        select(MedicationReminder).where(
            MedicationReminder.id == reminder_id,
            MedicationReminder.user_id == user_id,
            MedicationReminder.is_deleted == False,  # noqa: E712
        )
    )
    if not reminder:
        raise ApiError(status_code=status.HTTP_404_NOT_FOUND, detail="Medication reminder not found", error_code=ErrorCode.MEDICATION_REMINDER_NOT_FOUND)
    return reminder


@router.get("", response_model=list[MedicationReminderOut])
async def list_medication_reminders(
    current_user: CurrentUser,
    db: DB,
    family_member_id: uuid.UUID | None = None,
    status_filter: str | None = Query(None, alias="status"),
):
    q = select(MedicationReminder).where(
        MedicationReminder.user_id == current_user.id,
        MedicationReminder.is_deleted == False,  # noqa: E712
        family_scope(MedicationReminder, family_member_id),
    )
    if status_filter:
        if status_filter not in ("active", "paused", "completed"):
            raise ApiError(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid status filter", error_code=ErrorCode.INVALID_STATUS_FILTER)
        q = q.where(MedicationReminder.status == status_filter)
    items = (await db.scalars(q.order_by(MedicationReminder.created_at.desc()))).all()
    return [MedicationReminderOut.model_validate(i) for i in items]


@router.get("/{reminder_id}", response_model=MedicationReminderOut)
async def get_medication_reminder(reminder_id: uuid.UUID, current_user: CurrentUser, db: DB):
    return MedicationReminderOut.model_validate(await _get_reminder_or_404(db, reminder_id, current_user.id))


@router.post("", response_model=MedicationReminderOut, status_code=status.HTTP_201_CREATED)
async def create_medication_reminder(body: MedicationReminderCreateRequest, current_user: CurrentUser, db: DB):
    await validate_family_member_ownership(db, current_user.id, body.family_member_id)

    if body.source == "document":
        if not body.medication_request_id:
            raise ApiError(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="medication_request_id is required when source is 'document'",
                error_code=ErrorCode.MEDICATION_REQUEST_ID_REQUIRED,
            )
        source_med = await db.scalar(
            select(MedicationRequest).where(
                MedicationRequest.id == body.medication_request_id,
                MedicationRequest.user_id == current_user.id,
                MedicationRequest.is_deleted == False,  # noqa: E712
            )
        )
        if not source_med:
            raise ApiError(status_code=status.HTTP_404_NOT_FOUND, detail="Source medication not found", error_code=ErrorCode.SOURCE_MEDICATION_NOT_FOUND)

    if body.frequency_type == "specific_days" and not body.days_of_week:
        raise ApiError(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="days_of_week is required when frequency_type is 'specific_days'",
            error_code=ErrorCode.DAYS_OF_WEEK_REQUIRED,
        )
    if body.frequency_type == "interval" and not body.interval_days:
        raise ApiError(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="interval_days is required when frequency_type is 'interval'",
            error_code=ErrorCode.INTERVAL_DAYS_REQUIRED,
        )

    reminder = MedicationReminder(
        user_id=current_user.id,
        family_member_id=body.family_member_id,
        source=body.source,
        medication_request_id=body.medication_request_id,
        source_record_id=body.source_record_id,
        medication_name=body.medication_name,
        dosage=body.dosage,
        form=body.form,
        instructions=body.instructions,
        frequency_type=body.frequency_type,
        days_of_week=body.days_of_week,
        interval_days=body.interval_days,
        times_of_day=body.times_of_day,
        timezone=body.timezone,
        start_date=body.start_date,
        end_date=body.end_date,
        email_reminders_enabled=body.email_reminders_enabled,
        push_reminders_enabled=body.push_reminders_enabled,
        created_by_id=current_user.id,
    )
    db.add(reminder)
    await db.commit()
    await db.refresh(reminder)
    logger.info("Medication reminder created", reminder_id=str(reminder.id), user_id=str(current_user.id))
    return MedicationReminderOut.model_validate(reminder)


@router.patch("/{reminder_id}", response_model=MedicationReminderOut)
async def update_medication_reminder(
    reminder_id: uuid.UUID, body: MedicationReminderUpdateRequest, current_user: CurrentUser, db: DB
):
    reminder = await _get_reminder_or_404(db, reminder_id, current_user.id)
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(reminder, field, value)
    reminder.updated_by_id = current_user.id
    await db.commit()
    await db.refresh(reminder)
    logger.info("Medication reminder updated", reminder_id=str(reminder_id), user_id=str(current_user.id))
    return MedicationReminderOut.model_validate(reminder)


@router.delete("/{reminder_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_medication_reminder(reminder_id: uuid.UUID, current_user: CurrentUser, db: DB):
    reminder = await _get_reminder_or_404(db, reminder_id, current_user.id)
    reminder.is_deleted = True
    reminder.deleted_at = datetime.now(dt_timezone.utc)
    reminder.deleted_by_id = current_user.id
    await db.commit()
    logger.info("Medication reminder deleted", reminder_id=str(reminder_id), user_id=str(current_user.id))


@router.get("/{reminder_id}/schedule", response_model=list[UpcomingDoseOut])
async def get_reminder_schedule(
    reminder_id: uuid.UUID,
    current_user: CurrentUser,
    db: DB,
    days_ahead: int = Query(30, ge=1, le=90),
):
    """Upcoming dose instants for one reminder - mobile clients use this to schedule local alarms."""
    reminder = await _get_reminder_or_404(db, reminder_id, current_user.id)
    now = datetime.now(dt_timezone.utc)
    window_end = now + timedelta(days=days_ahead)
    instants = occurrences_between(reminder, now, window_end)
    return [
        UpcomingDoseOut(
            reminder_id=reminder.id,
            family_member_id=reminder.family_member_id,
            medication_name=reminder.medication_name,
            dosage=reminder.dosage,
            instructions=reminder.instructions,
            scheduled_at=instant,
            timezone=reminder.timezone,
        )
        for instant in instants
    ]


@router.get("/upcoming/all", response_model=list[UpcomingDoseOut])
async def list_upcoming_doses(
    current_user: CurrentUser,
    db: DB,
    family_member_id: uuid.UUID | None = None,
    hours_ahead: int = Query(24, ge=1, le=168),
):
    """Upcoming doses across all (or one family member's) active reminders, soonest first."""
    q = select(MedicationReminder).where(
        MedicationReminder.user_id == current_user.id,
        MedicationReminder.is_deleted == False,  # noqa: E712
        MedicationReminder.status == "active",
    )
    if family_member_id is not None:
        q = q.where(family_scope(MedicationReminder, family_member_id))
    reminders = (await db.scalars(q)).all()

    now = datetime.now(dt_timezone.utc)
    window_end = now + timedelta(hours=hours_ahead)

    doses: list[UpcomingDoseOut] = []
    for reminder in reminders:
        for instant in occurrences_between(reminder, now, window_end):
            doses.append(
                UpcomingDoseOut(
                    reminder_id=reminder.id,
                    family_member_id=reminder.family_member_id,
                    medication_name=reminder.medication_name,
                    dosage=reminder.dosage,
                    instructions=reminder.instructions,
                    scheduled_at=instant,
                    timezone=reminder.timezone,
                )
            )
    doses.sort(key=lambda d: d.scheduled_at)
    return doses


@router.post("/{reminder_id}/doses/status", response_model=DoseLogOut)
async def set_dose_status(reminder_id: uuid.UUID, body: DoseStatusUpdateRequest, current_user: CurrentUser, db: DB):
    """Mark a specific scheduled dose occurrence as taken or skipped, creating its log row if needed."""
    reminder = await _get_reminder_or_404(db, reminder_id, current_user.id)

    dose_log = await db.scalar(
        select(MedicationDoseLog).where(
            MedicationDoseLog.reminder_id == reminder.id,
            MedicationDoseLog.scheduled_at == body.scheduled_at,
        )
    )
    if not dose_log:
        dose_log = MedicationDoseLog(
            reminder_id=reminder.id,
            user_id=current_user.id,
            family_member_id=reminder.family_member_id,
            scheduled_at=body.scheduled_at,
        )
        db.add(dose_log)

    dose_log.status = body.status
    if body.status == "taken":
        dose_log.taken_at = datetime.now(dt_timezone.utc)
    await db.commit()
    await db.refresh(dose_log)
    logger.info(
        "Medication dose status updated",
        reminder_id=str(reminder_id), dose_status=body.status, user_id=str(current_user.id),
    )
    return DoseLogOut.model_validate(dose_log)


@router.get("/{reminder_id}/doses", response_model=list[DoseLogOut])
async def list_dose_logs(
    reminder_id: uuid.UUID,
    current_user: CurrentUser,
    db: DB,
    since: date | None = None,
):
    reminder = await _get_reminder_or_404(db, reminder_id, current_user.id)
    q = select(MedicationDoseLog).where(MedicationDoseLog.reminder_id == reminder.id)
    if since:
        q = q.where(MedicationDoseLog.scheduled_at >= datetime(since.year, since.month, since.day, tzinfo=dt_timezone.utc))
    items = (await db.scalars(q.order_by(MedicationDoseLog.scheduled_at.desc()))).all()
    return [DoseLogOut.model_validate(i) for i in items]
