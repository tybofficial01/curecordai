"""
In-process asyncio loop (no Celery/Redis in this codebase - mirrors the BackgroundTasks-only
approach used by tasks/process_record.py) that ticks every minute, finds medication doses due
in the tick's window, and emails a reminder for each - the Web app's reminder channel. Mobile
clients handle their own alarm-style local notifications from the same /medications schedule
API, so this worker never needs to know about push tokens/platforms.
"""
import asyncio
from datetime import datetime, timedelta, timezone as dt_timezone

import structlog
from sqlalchemy import select

from app.core.enums import Language
from app.database import AsyncSessionLocal
from app.models.auth import User
from app.models.family import FamilyMember
from app.models.medication_reminder import MedicationDoseLog, MedicationReminder
from app.models.settings import AppSetting
from app.services.medication_schedule import occurrences_between
from app.services.twilio_service import twilio_service

logger = structlog.get_logger()

_TICK_SECONDS = 60


async def _dispatch_due_reminders() -> None:
    now = datetime.now(dt_timezone.utc)
    # A dose exactly at 08:00:00 must not be skipped just because the tick fires at 08:00:03,
    # so the window is [now - tick, now] rather than a forward-looking slice.
    window_start = now - timedelta(seconds=_TICK_SECONDS)

    async with AsyncSessionLocal() as db:
        reminders = (
            await db.scalars(
                select(MedicationReminder).where(
                    MedicationReminder.is_deleted == False,  # noqa: E712
                    MedicationReminder.status == "active",
                    MedicationReminder.email_reminders_enabled == True,  # noqa: E712
                )
            )
        ).all()

        for reminder in reminders:
            try:
                due = occurrences_between(reminder, window_start, now)
            except Exception:
                logger.exception("Failed to compute occurrences for reminder", reminder_id=str(reminder.id))
                continue
            for scheduled_at in due:
                await _send_one_reminder(db, reminder, scheduled_at)


async def _send_one_reminder(db, reminder: MedicationReminder, scheduled_at: datetime) -> None:
    existing = await db.scalar(
        select(MedicationDoseLog).where(
            MedicationDoseLog.reminder_id == reminder.id,
            MedicationDoseLog.scheduled_at == scheduled_at,
        )
    )
    if existing:
        return  # already logged (sent, or already acted on by the user) - idempotent

    dose_log = MedicationDoseLog(
        reminder_id=reminder.id,
        user_id=reminder.user_id,
        family_member_id=reminder.family_member_id,
        scheduled_at=scheduled_at,
        status="pending",
    )
    db.add(dose_log)
    try:
        await db.commit()
    except Exception:
        # Unique constraint hit - another tick/worker instance already claimed this dose.
        await db.rollback()
        return

    user = await db.get(User, reminder.user_id)
    if not user or not user.email or user.is_deleted:
        return

    app_setting = await db.scalar(select(AppSetting).where(AppSetting.user_id == reminder.user_id))
    if app_setting and not app_setting.email_notifications_enabled:
        return

    # None = the dose is the account owner's own; the email template substitutes a
    # localized "you". A family member's real name is passed through untranslated.
    recipient_label: str | None = None
    if reminder.family_member_id:
        member = await db.get(FamilyMember, reminder.family_member_id)
        if member:
            recipient_label = member.full_name

    language = Language.EN
    if app_setting and app_setting.language:
        try:
            language = Language(app_setting.language)
        except ValueError:
            logger.warning(
                "Unrecognized saved language on app setting - falling back to English",
                user_id=str(reminder.user_id),
            )

    local_time = scheduled_at.astimezone().strftime("%I:%M %p")
    try:
        from app.services.medication_schedule import safe_zoneinfo

        local_time = scheduled_at.astimezone(safe_zoneinfo(reminder.timezone)).strftime("%I:%M %p %Z")
    except Exception:
        pass

    sent = await twilio_service.send_medication_reminder_email(
        email=user.email,
        recipient_label=recipient_label,
        medication_name=reminder.medication_name,
        dosage=reminder.dosage,
        scheduled_local_time=local_time,
        language=language,
    )

    dose_log.status = "sent" if sent else "pending"
    if sent:
        dose_log.email_sent_at = datetime.now(dt_timezone.utc)
    await db.commit()


async def run_medication_reminder_worker(stop_event: asyncio.Event) -> None:
    logger.info("Medication reminder worker started", tick_seconds=_TICK_SECONDS)
    while not stop_event.is_set():
        try:
            await _dispatch_due_reminders()
        except Exception:
            logger.exception("Medication reminder tick failed")
        try:
            await asyncio.wait_for(stop_event.wait(), timeout=_TICK_SECONDS)
        except asyncio.TimeoutError:
            pass
    logger.info("Medication reminder worker stopped")
