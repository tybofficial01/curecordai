import uuid
from datetime import date, datetime

from pydantic import BaseModel, ConfigDict, Field


# ── Folders ───────────────────────────────────────────────────────────────────

class FolderCreateRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    icon: str | None = Field(None, max_length=50)
    sort_order: int = 0


class FolderUpdateRequest(BaseModel):
    name: str | None = Field(None, min_length=1, max_length=100)
    icon: str | None = None
    sort_order: int | None = None


class FolderOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    user_id: uuid.UUID
    name: str
    icon: str | None
    sort_order: int
    created_at: datetime
    updated_at: datetime


# ── Records ───────────────────────────────────────────────────────────────────

VALID_RECORD_TYPES = {
    "lab_report", "prescription", "radiology", "discharge_summary",
    "vaccination", "insurance", "referral", "other",
}


class RecordUploadInitRequest(BaseModel):
    file_name: str = Field(..., min_length=1, max_length=255)
    file_mime_type: str
    file_size_bytes: int = Field(..., gt=0)
    title: str = Field("Untitled", min_length=1, max_length=255)
    record_type: str = "other"
    folder_id: uuid.UUID | None = None
    family_member_id: uuid.UUID | None = None
    record_date: date | None = None


class RecordUploadInitResponse(BaseModel):
    record_id: uuid.UUID
    upload_url: str
    # Presigned POST - the client must send a multipart/form-data POST to upload_url with
    # every entry here as a form field, plus the file itself as the final field named "file".
    upload_fields: dict[str, str]
    object_key: str
    expires_in_seconds: int


class RecordConfirmUploadRequest(BaseModel):
    file_hash: str | None = Field(None, min_length=64, max_length=64)  # SHA-256


class RecordUpdateRequest(BaseModel):
    title: str | None = Field(None, min_length=1, max_length=255)
    folder_id: uuid.UUID | None = None
    record_date: date | None = None
    patient_name_on_doc: str | None = None
    laboratory_name: str | None = None
    referring_doctor: str | None = None


class RecordOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    user_id: uuid.UUID
    family_member_id: uuid.UUID | None
    folder_id: uuid.UUID | None
    title: str
    record_type: str
    record_date: date | None
    document_date: date | None
    file_name: str
    file_mime_type: str
    file_size_bytes: int
    processing_status: str
    processing_error: str | None
    ai_summary: str | None
    ai_summary_generated_at: datetime | None
    ai_analysis: dict | None = None
    is_dicom: bool
    patient_name_on_doc: str | None
    laboratory_name: str | None
    issuing_organization: str | None
    referring_doctor: str | None
    uploaded_at: datetime
    created_at: datetime
    # Injected server-side - not stored
    download_url: str | None = None


class RecordClinicalOut(BaseModel):
    conditions: list[dict]
    medications: list[dict]
    observations: list[dict]
    allergies: list[dict]
    encounters: list[dict]


class RecordFullOut(RecordOut):
    # Injected server-side - the record's extracted clinical entities, fetched in the
    # same request so the client doesn't need a second round trip to render the detail screen.
    clinical: RecordClinicalOut | None = None
