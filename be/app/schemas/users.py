import uuid
from datetime import date, datetime

from pydantic import BaseModel, ConfigDict, Field


class ProfileUpdateRequest(BaseModel):
    full_name: str | None = Field(None, min_length=2, max_length=255)
    date_of_birth: date | None = None
    gender: str | None = None
    height_cm: float | None = None
    weight_kg: float | None = None
    blood_group: str | None = None


class ProfilePhotoUploadRequest(BaseModel):
    filename: str
    content_type: str


class ProfilePhotoUploadResponse(BaseModel):
    upload_url: str
    object_key: str
    expires_in_seconds: int


class ProfileOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    user_id: uuid.UUID
    patient_id_display: str | None
    full_name: str
    date_of_birth: date | None
    gender: str | None
    height_cm: float | None
    weight_kg: float | None
    blood_group: str | None
    bmi: float | None
    profile_photo_url: str | None
    profile_completion_pct: int
    created_at: datetime
    updated_at: datetime


class OnboardingRequest(BaseModel):
    full_name: str | None = None
    year_of_birth: int | None = None
    gender: str | None = None
    height_cm: float | None = None
    weight_kg: float | None = None
    blood_group: str | None = None
    allergies: str | None = None
    existing_conditions: list[str] | None = None


class MeOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    phone_number: str | None
    email: str | None
    auth_provider: str
    is_active: bool
    is_email_verified: bool
    is_phone_verified: bool
    mfa_enabled: bool
    data_region: str
    last_login_at: datetime | None
    created_at: datetime
    profile: ProfileOut | None = None
