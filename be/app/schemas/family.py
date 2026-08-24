import uuid
from datetime import date, datetime

from pydantic import BaseModel, ConfigDict, Field


class FamilyMemberCreateRequest(BaseModel):
    full_name: str = Field(..., min_length=2, max_length=255)
    relationship: str = Field(..., min_length=1, max_length=50)
    role: str = Field(..., pattern="^(caregiver|dependent)$")
    access_level: str = Field("full", pattern="^(full|vitals_only|read_only)$")
    date_of_birth: date | None = None
    gender: str | None = Field(None, pattern="^(male|female|other|unknown)$")
    blood_group: str | None = Field(None, pattern="^(A\+|A-|B\+|B-|AB\+|AB-|O\+|O-|unknown)$")


class FamilyMemberUpdateRequest(BaseModel):
    full_name: str | None = Field(None, min_length=2, max_length=255)
    relationship: str | None = Field(None, min_length=1, max_length=50)
    access_level: str | None = Field(None, pattern="^(full|vitals_only|read_only)$")
    date_of_birth: date | None = None
    gender: str | None = Field(None, pattern="^(male|female|other|unknown)$")
    blood_group: str | None = Field(None, pattern="^(A\+|A-|B\+|B-|AB\+|AB-|O\+|O-|unknown)$")


class FamilyMemberOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    owner_user_id: uuid.UUID
    full_name: str
    relationship: str
    role: str
    access_level: str
    date_of_birth: date | None
    age: int | None
    gender: str | None
    blood_group: str | None
    photo_url: str | None
    fhir_patient_id: str | None
    created_at: datetime
    updated_at: datetime


class FamilyMemberPhotoUploadResponse(BaseModel):
    upload_url: str
    object_key: str
    expires_in_seconds: int
