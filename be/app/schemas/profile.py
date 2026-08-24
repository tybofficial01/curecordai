import uuid
from datetime import date, datetime
from typing import Literal, Optional

from pydantic import BaseModel, ConfigDict, Field, field_validator


class ProfileInfoSchema(BaseModel):
    full_name: str = Field(..., min_length=1, max_length=255)
    date_of_birth: Optional[date] = None
    gender: Optional[str] = None      # normalised to lowercase in the endpoint
    phone_number: Optional[str] = Field(None, max_length=20)

    @field_validator("phone_number")
    @classmethod
    def _validate_phone_number(cls, value: Optional[str]) -> Optional[str]:
        if value is None or value.strip() == "":
            return None
        if len(value) < 7:
            raise ValueError("Phone number must be at least 7 characters")
        return value


class PhysicalMetricsSchema(BaseModel):
    height_cm: Optional[float] = Field(None, ge=50, le=300)
    weight_kg: Optional[float] = Field(None, ge=10, le=500)
    blood_group: Optional[Literal["A+", "A-", "B+", "B-", "O+", "O-", "AB+", "AB-"]] = None


class HealthDetailsSchema(BaseModel):
    allergies: str = ""          # comma-separated string from frontend; split on save
    conditions: list[str] = Field(default_factory=list)


class PreferencesSchema(BaseModel):
    language: Literal["en", "ur"]
    is_dark_theme: bool


class PrivacySchema(BaseModel):
    biometric_lock: bool
    app_lock_on_background: bool = False
    screenshot_prevention: bool = False


class DataSharingSchema(BaseModel):
    name: str = Field(..., min_length=1, max_length=255)
    access_type: Literal["read", "full"]
    granted_until: Optional[date] = None


class DataSharingResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    name: str
    access_type: str
    granted_until: Optional[date]
    status: str
    created_at: datetime


class PhysicalMetricsResponse(BaseModel):
    bmi: Optional[float]
    message: str


class FullProfileResponse(BaseModel):
    patient_id_display: Optional[str]
    profile_photo_url: Optional[str]
    full_name: str
    date_of_birth: Optional[date]
    gender: Optional[str]
    phone_number: Optional[str]
    height_cm: Optional[float]
    weight_kg: Optional[float]
    blood_group: Optional[str]
    bmi: Optional[float]
    language: str
    theme: str
    biometric_lock: bool
    allergies: Optional[str]           # comma-joined string for Flutter
    conditions: list[str]
    profile_completion_pct: int
