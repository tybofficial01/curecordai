import uuid
from datetime import date, datetime
from typing import Any

from pydantic import BaseModel, ConfigDict, Field


# ── Allergy ───────────────────────────────────────────────────────────────────

class AllergyCreateRequest(BaseModel):
    substance_name: str = Field(..., min_length=1, max_length=255)
    category: str | None = Field(None, pattern="^(food|medication|environment|biologic)$")
    criticality: str | None = Field(None, pattern="^(low|high|unable-to-assess)$")
    clinical_status: str = Field("active", pattern="^(active|inactive|resolved)$")
    verification_status: str = Field("unconfirmed", pattern="^(unconfirmed|confirmed|refuted|entered-in-error)$")
    snomed_code: str | None = None
    snomed_display: str | None = None
    reaction_description: str | None = None
    onset_date: date | None = None
    family_member_id: uuid.UUID | None = None


class AllergyUpdateRequest(BaseModel):
    substance_name: str | None = Field(None, min_length=1, max_length=255)
    category: str | None = None
    criticality: str | None = None
    clinical_status: str | None = None
    reaction_description: str | None = None


class AllergyOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    user_id: uuid.UUID
    family_member_id: uuid.UUID | None
    substance_name: str
    category: str | None
    criticality: str | None
    clinical_status: str
    verification_status: str
    snomed_code: str | None
    snomed_display: str | None
    reaction_description: str | None
    onset_date: date | None
    ai_extracted: bool
    ai_confidence: float | None
    source: str
    created_at: datetime
    updated_at: datetime


# ── Condition ─────────────────────────────────────────────────────────────────

class ConditionCreateRequest(BaseModel):
    condition_name: str = Field(..., min_length=1, max_length=255)
    clinical_status: str = Field("active", pattern="^(active|recurrence|relapse|inactive|remission|resolved)$")
    verification_status: str = Field("unconfirmed", pattern="^(unconfirmed|confirmed|refuted|entered-in-error)$")
    severity: str | None = Field(None, pattern="^(mild|moderate|severe)$")
    icd11_code: str | None = Field(None, max_length=30)
    icd11_display: str | None = None
    snomed_code: str | None = None
    onset_date: date | None = None
    abatement_date: date | None = None
    attending_physician: str | None = None
    care_plan_notes: str | None = None
    family_member_id: uuid.UUID | None = None


class ConditionUpdateRequest(BaseModel):
    condition_name: str | None = None
    clinical_status: str | None = None
    severity: str | None = None
    abatement_date: date | None = None
    care_plan_notes: str | None = None


class ConditionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    user_id: uuid.UUID
    family_member_id: uuid.UUID | None
    condition_name: str
    clinical_status: str
    verification_status: str
    severity: str | None
    icd11_code: str | None
    icd11_display: str | None
    snomed_code: str | None
    onset_date: date | None
    abatement_date: date | None
    attending_physician: str | None
    care_plan_notes: str | None
    ai_extracted: bool
    ai_confidence: float | None
    source: str
    created_at: datetime
    updated_at: datetime


# ── Medication Request ─────────────────────────────────────────────────────────

class MedicationRequestUpdateRequest(BaseModel):
    medication_name_raw: str | None = Field(None, min_length=1, max_length=255)
    dosage_instruction: str | None = None
    dose_quantity: str | None = None
    dose_frequency: str | None = None
    route: str | None = None
    status: str | None = Field(None, pattern="^(active|on-hold|cancelled|completed|entered-in-error|stopped|draft|unknown)$")
    intent: str | None = Field(None, pattern="^(proposal|plan|order|original-order|reflex-order|filler-order|instance-order|option)$")
    prescribing_doctor: str | None = None
    prescribed_date: date | None = None
    start_date: date | None = None
    end_date: date | None = None
    duration_days: int | None = None


class MedicationRequestCreateRequest(BaseModel):
    medication_name_raw: str = Field(..., min_length=1, max_length=255)
    dosage_instruction: str | None = None
    dose_quantity: str | None = None
    dose_frequency: str | None = None
    route: str | None = None
    status: str = Field("active", pattern="^(active|on-hold|cancelled|completed|entered-in-error|stopped|draft|unknown)$")
    intent: str = Field("order", pattern="^(proposal|plan|order|original-order|reflex-order|filler-order|instance-order|option)$")
    prescribing_doctor: str | None = None
    prescribed_date: date | None = None
    start_date: date | None = None
    end_date: date | None = None
    duration_days: int | None = None
    family_member_id: uuid.UUID | None = None


class MedicationRequestOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    user_id: uuid.UUID
    family_member_id: uuid.UUID | None
    medication_name_raw: str
    dosage_instruction: str | None
    dose_quantity: str | None
    dose_frequency: str | None
    route: str | None
    status: str
    intent: str
    prescribing_doctor: str | None
    prescribed_date: date | None
    start_date: date | None
    end_date: date | None
    duration_days: int | None
    ai_extracted: bool
    ai_confidence: float | None
    source_record_id: uuid.UUID | None
    created_at: datetime
    updated_at: datetime
    # True only when the user has added this extracted medication as an active
    # reminder (see MedicationReminder) - extraction alone never makes a medication
    # "active". Computed server-side, not a column on medication_requests.
    has_active_reminder: bool = False


# ── Observation ───────────────────────────────────────────────────────────────

class ObservationUpdateRequest(BaseModel):
    observation_name: str | None = Field(None, min_length=1, max_length=255)
    status: str | None = Field(None, pattern="^(registered|preliminary|final|amended|corrected|cancelled|entered-in-error|unknown)$")
    value_quantity: float | None = None
    value_unit: str | None = Field(None, max_length=50)
    value_string: str | None = None
    interpretation: str | None = Field(None, pattern="^(N|L|H|LL|HH|A|AA|U|D|B|W|S|R|I|MS|VS)$")
    effective_datetime: datetime | None = None
    loinc_code: str | None = Field(None, max_length=20)
    loinc_display: str | None = None
    body_site: str | None = None


class ObservationCreateRequest(BaseModel):
    observation_name: str = Field(..., min_length=1, max_length=255)
    observation_category: str = Field(..., pattern="^(vital-signs|laboratory|imaging|procedure|survey|exam|therapy|activity)$")
    loinc_code: str | None = Field(None, max_length=20)
    loinc_display: str | None = None
    status: str = Field("final", pattern="^(registered|preliminary|final|amended|corrected|cancelled|entered-in-error|unknown)$")
    value_quantity: float | None = None
    value_unit: str | None = Field(None, max_length=50)
    value_string: str | None = None
    reference_range_low: float | None = None
    reference_range_high: float | None = None
    interpretation: str | None = Field(None, pattern="^(N|L|H|LL|HH|A|AA|U|D|B|W|S|R|I|MS|VS)$")
    effective_datetime: datetime | None = None
    body_site: str | None = None
    family_member_id: uuid.UUID | None = None


class ObservationOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    user_id: uuid.UUID
    family_member_id: uuid.UUID | None
    observation_name: str
    observation_category: str
    loinc_code: str | None
    loinc_display: str | None
    status: str
    value_quantity: float | None
    value_unit: str | None
    value_string: str | None
    reference_range_low: float | None
    reference_range_high: float | None
    interpretation: str | None
    effective_datetime: datetime | None
    body_site: str | None
    ai_extracted: bool
    ai_confidence: float | None
    source_record_id: uuid.UUID | None
    created_at: datetime
    updated_at: datetime


# ── Encounter ─────────────────────────────────────────────────────────────────

class EncounterCreateRequest(BaseModel):
    title: str = Field(..., min_length=1, max_length=255)
    encounter_type: str = Field(..., pattern="^(ambulatory|emergency|inpatient|home-health|virtual|observation|vaccination)$")
    status: str = Field("finished", pattern="^(planned|arrived|triaged|in-progress|on-hold|discharged|finished|cancelled|entered-in-error|unknown)$")
    description: str | None = None
    practitioner_name: str | None = None
    practitioner_specialty: str | None = None
    organization_name: str | None = None
    start_datetime: datetime | None = None
    end_datetime: datetime | None = None
    batch_number: str | None = None
    family_member_id: uuid.UUID | None = None


class EncounterUpdateRequest(BaseModel):
    title: str | None = Field(None, min_length=1, max_length=255)
    encounter_type: str | None = Field(None, pattern="^(ambulatory|emergency|inpatient|home-health|virtual|observation|vaccination)$")
    status: str | None = Field(None, pattern="^(planned|arrived|triaged|in-progress|on-hold|discharged|finished|cancelled|entered-in-error|unknown)$")
    description: str | None = None
    practitioner_name: str | None = None
    practitioner_specialty: str | None = None
    organization_name: str | None = None
    start_datetime: datetime | None = None
    end_datetime: datetime | None = None


class EncounterOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    user_id: uuid.UUID
    family_member_id: uuid.UUID | None
    title: str
    encounter_type: str
    status: str
    description: str | None
    practitioner_name: str | None
    practitioner_specialty: str | None
    organization_name: str | None
    start_datetime: datetime | None
    end_datetime: datetime | None
    batch_number: str | None
    ai_extracted: bool
    ai_confidence: float | None
    source_record_id: uuid.UUID | None
    created_at: datetime
    updated_at: datetime
