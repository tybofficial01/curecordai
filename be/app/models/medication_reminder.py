import uuid
from datetime import date, datetime

from sqlalchemy import Boolean, Date, DateTime, ForeignKey, Index, String, UniqueConstraint, func, text
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.encryption import EncryptedString
from app.database import Base
from app.models.base import AuditMixin, SoftDeleteMixin


class MedicationReminder(Base, AuditMixin, SoftDeleteMixin):
    """
    A user-managed medication + reminder schedule. Distinct from clinical.MedicationRequest
    (which is the FHIR-aligned record of what a document says a patient was prescribed) -
    a reminder is created FROM a MedicationRequest (source='document') or typed in directly
    (source='manual'), and owns the recurring dosing schedule + notification preferences.
    """
    __tablename__ = "medication_reminders"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    family_member_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("family_members.id", ondelete="SET NULL"),
        nullable=True,
    )

    source: Mapped[str] = mapped_column(String(20), default="manual", nullable=False)  # manual | document
    medication_request_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("medication_requests.id", ondelete="SET NULL"),
        nullable=True,
    )
    source_record_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("medical_records.id", ondelete="SET NULL"),
        nullable=True,
    )

    medication_name: Mapped[str] = mapped_column(EncryptedString, nullable=False)
    dosage: Mapped[str | None] = mapped_column(String(100), nullable=True)
    form: Mapped[str | None] = mapped_column(String(50), nullable=True)
    instructions: Mapped[str | None] = mapped_column(EncryptedString, nullable=True)

    # Recurrence: 'daily' every day, 'specific_days' uses days_of_week, 'interval' every N days,
    # 'as_needed' has no fixed schedule (no reminders are ever generated for it).
    frequency_type: Mapped[str] = mapped_column(String(20), default="daily", nullable=False)
    days_of_week: Mapped[list[int] | None] = mapped_column(JSONB, nullable=True)  # 0=Mon .. 6=Sun
    interval_days: Mapped[int | None] = mapped_column(nullable=True)
    times_of_day: Mapped[list[str]] = mapped_column(JSONB, nullable=False)  # ["08:00", "20:00"]

    # IANA tz name the schedule was authored in (e.g. "Asia/Kolkata") - every dose time is
    # interpreted in this zone so DST/offset shifts never move the wall-clock reminder time.
    timezone: Mapped[str] = mapped_column(String(64), default="UTC", nullable=False)

    start_date: Mapped[date] = mapped_column(Date, nullable=False)
    end_date: Mapped[date | None] = mapped_column(Date, nullable=True)

    status: Mapped[str] = mapped_column(String(20), default="active", nullable=False)  # active|paused|completed

    email_reminders_enabled: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    push_reminders_enabled: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    dose_logs: Mapped[list["MedicationDoseLog"]] = relationship(
        "MedicationDoseLog", back_populates="reminder", cascade="all, delete-orphan"
    )

    __table_args__ = (
        Index("idx_med_reminders_user_id", "user_id"),
        Index("idx_med_reminders_user_active", "user_id", "is_deleted", "status"),
        Index("idx_med_reminders_family_member_id", "family_member_id"),
        Index("idx_med_reminders_medication_request_id", "medication_request_id"),
    )


class MedicationDoseLog(Base):
    """
    One row per scheduled dose occurrence. Created by the reminder worker when a dose's send
    window arrives (email channel) and/or by the client when it schedules a local notification
    (push channel) - the (reminder_id, scheduled_at) unique constraint makes email dispatch
    idempotent across worker restarts/overlapping ticks.
    """
    __tablename__ = "medication_dose_logs"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    reminder_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("medication_reminders.id", ondelete="CASCADE"),
        nullable=False,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    family_member_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("family_members.id", ondelete="SET NULL"),
        nullable=True,
    )

    scheduled_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)

    status: Mapped[str] = mapped_column(String(20), default="pending", nullable=False)  # pending|sent|taken|skipped|missed
    email_sent_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    taken_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    reminder: Mapped["MedicationReminder"] = relationship("MedicationReminder", back_populates="dose_logs")

    __table_args__ = (
        UniqueConstraint("reminder_id", "scheduled_at", name="uq_dose_log_reminder_scheduled_at"),
        Index("idx_dose_logs_user_id", "user_id"),
        Index("idx_dose_logs_reminder_id", "reminder_id"),
        Index("idx_dose_logs_status_scheduled", "status", "scheduled_at"),
    )
