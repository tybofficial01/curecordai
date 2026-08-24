import uuid
from datetime import date, datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

_FREQUENCY_TYPES = ("daily", "specific_days", "interval", "as_needed")
_STATUSES = ("active", "paused", "completed")
_SOURCES = ("manual", "document")
_TIME_RE = r"^([01]\d|2[0-3]):[0-5]\d$"


class MedicationReminderCreateRequest(BaseModel):
    family_member_id: uuid.UUID | None = None
    source: str = Field("manual", pattern="^(manual|document)$")
    medication_request_id: uuid.UUID | None = None
    source_record_id: uuid.UUID | None = None

    medication_name: str = Field(..., min_length=1, max_length=255)
    dosage: str | None = Field(None, max_length=100)
    form: str | None = Field(None, max_length=50)
    instructions: str | None = None

    frequency_type: str = Field("daily", pattern="^(daily|specific_days|interval|as_needed)$")
    days_of_week: list[int] | None = None
    interval_days: int | None = Field(None, ge=1, le=90)
    # "as_needed" reminders have no fixed dosing time, so this is the one frequency_type
    # allowed to submit an empty list - every other type requires at least one time, enforced
    # below in _validate_times_required (a plain Field(min_length=1) can't see frequency_type).
    times_of_day: list[str] = Field(default_factory=list, max_length=12)

    timezone: str = Field("UTC", min_length=1, max_length=64)
    start_date: date
    end_date: date | None = None

    email_reminders_enabled: bool = True
    push_reminders_enabled: bool = True

    @field_validator("times_of_day")
    @classmethod
    def _validate_times(cls, v: list[str]) -> list[str]:
        import re
        for t in v:
            if not re.match(_TIME_RE, t):
                raise ValueError(f"Invalid time '{t}', expected HH:MM (24h)")
        return v

    @field_validator("days_of_week")
    @classmethod
    def _validate_days(cls, v: list[int] | None) -> list[int] | None:
        if v is None:
            return v
        if any(d < 0 or d > 6 for d in v):
            raise ValueError("days_of_week entries must be 0 (Mon) through 6 (Sun)")
        return v

    @field_validator("end_date")
    @classmethod
    def _validate_end_after_start(cls, v: date | None, info) -> date | None:
        start = info.data.get("start_date")
        if v and start and v < start:
            raise ValueError("end_date cannot be before start_date")
        return v

    @model_validator(mode="after")
    def _validate_times_required(self):
        if self.frequency_type != "as_needed" and len(self.times_of_day) < 1:
            raise ValueError("times_of_day must have at least one entry unless frequency_type is 'as_needed'")
        return self


class MedicationReminderUpdateRequest(BaseModel):
    medication_name: str | None = Field(None, min_length=1, max_length=255)
    dosage: str | None = Field(None, max_length=100)
    form: str | None = Field(None, max_length=50)
    instructions: str | None = None

    frequency_type: str | None = Field(None, pattern="^(daily|specific_days|interval|as_needed)$")
    days_of_week: list[int] | None = None
    interval_days: int | None = Field(None, ge=1, le=90)
    # No min_length here (unlike create): an update may be switching frequency_type to
    # "as_needed" in the same request, which legitimately clears times_of_day to [].
    times_of_day: list[str] | None = Field(None, max_length=12)

    timezone: str | None = Field(None, min_length=1, max_length=64)
    start_date: date | None = None
    end_date: date | None = None

    status: str | None = Field(None, pattern="^(active|paused|completed)$")
    email_reminders_enabled: bool | None = None
    push_reminders_enabled: bool | None = None

    @field_validator("times_of_day")
    @classmethod
    def _validate_times(cls, v: list[str] | None) -> list[str] | None:
        import re
        if v is None:
            return v
        for t in v:
            if not re.match(_TIME_RE, t):
                raise ValueError(f"Invalid time '{t}', expected HH:MM (24h)")
        return v


class MedicationReminderOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    user_id: uuid.UUID
    family_member_id: uuid.UUID | None
    source: str
    medication_request_id: uuid.UUID | None
    source_record_id: uuid.UUID | None

    medication_name: str
    dosage: str | None
    form: str | None
    instructions: str | None

    frequency_type: str
    days_of_week: list[int] | None
    interval_days: int | None
    times_of_day: list[str]

    timezone: str
    start_date: date
    end_date: date | None

    status: str
    email_reminders_enabled: bool
    push_reminders_enabled: bool

    created_at: datetime
    updated_at: datetime


class UpcomingDoseOut(BaseModel):
    reminder_id: uuid.UUID
    family_member_id: uuid.UUID | None
    medication_name: str
    dosage: str | None
    instructions: str | None
    scheduled_at: datetime
    timezone: str
    dose_log_id: uuid.UUID | None = None
    dose_status: str = "pending"


class DoseLogOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    reminder_id: uuid.UUID
    family_member_id: uuid.UUID | None
    scheduled_at: datetime
    status: str
    email_sent_at: datetime | None
    taken_at: datetime | None
    created_at: datetime


class DoseStatusUpdateRequest(BaseModel):
    status: str = Field(..., pattern="^(taken|skipped)$")
    scheduled_at: datetime
