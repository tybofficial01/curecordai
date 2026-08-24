import uuid
from datetime import date, datetime

from sqlalchemy import Boolean, Date, DateTime, ForeignKey, Index, Integer, Numeric, String, func, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.encryption import EncryptedString
from app.database import Base
from app.models.base import AuditMixin, SoftDeleteMixin


class AllergyIntolerance(Base, AuditMixin, SoftDeleteMixin):
    __tablename__ = "allergy_intolerances"

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

    fhir_resource_id: Mapped[str | None] = mapped_column(String(255), nullable=True)

    substance_name: Mapped[str] = mapped_column(EncryptedString, nullable=False)
    snomed_code: Mapped[str | None] = mapped_column(String(50), nullable=True)
    snomed_display: Mapped[str | None] = mapped_column(EncryptedString, nullable=True)

    category: Mapped[str | None] = mapped_column(String(20), nullable=True)
    criticality: Mapped[str | None] = mapped_column(String(30), nullable=True)

    clinical_status: Mapped[str] = mapped_column(String(20), default="active", nullable=False)
    verification_status: Mapped[str] = mapped_column(String(30), default="unconfirmed", nullable=False)

    reaction_description: Mapped[str | None] = mapped_column(EncryptedString, nullable=True)

    source: Mapped[str] = mapped_column(String(30), default="patient_reported", nullable=False)
    source_record_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)

    onset_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    recorded_date: Mapped[date | None] = mapped_column(Date, nullable=True)

    ai_extracted: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    ai_confidence: Mapped[float | None] = mapped_column(Numeric(5, 4), nullable=True)
    ai_correction_flag: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    ai_correction_note: Mapped[str | None] = mapped_column(EncryptedString, nullable=True)

    __table_args__ = (
        Index("idx_allergies_user_id", "user_id"),
        Index("idx_allergies_user_status", "user_id", "clinical_status"),
        Index("idx_allergies_snomed", "snomed_code"),
        Index("idx_allergies_source_record", "source_record_id"),
    )


class Condition(Base, AuditMixin, SoftDeleteMixin):
    __tablename__ = "conditions"

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

    fhir_resource_id: Mapped[str | None] = mapped_column(String(255), nullable=True)

    condition_name: Mapped[str] = mapped_column(EncryptedString, nullable=False)

    icd11_code: Mapped[str | None] = mapped_column(String(30), nullable=True)
    icd11_display: Mapped[str | None] = mapped_column(EncryptedString, nullable=True)

    snomed_code: Mapped[str | None] = mapped_column(String(50), nullable=True)
    snomed_display: Mapped[str | None] = mapped_column(EncryptedString, nullable=True)

    category: Mapped[str | None] = mapped_column(String(30), nullable=True)
    clinical_status: Mapped[str] = mapped_column(String(20), default="active", nullable=False)
    verification_status: Mapped[str] = mapped_column(String(30), default="unconfirmed", nullable=False)
    severity: Mapped[str | None] = mapped_column(String(20), nullable=True)

    onset_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    abatement_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    attending_physician: Mapped[str | None] = mapped_column(EncryptedString, nullable=True)
    care_plan_notes: Mapped[str | None] = mapped_column(EncryptedString, nullable=True)

    source: Mapped[str] = mapped_column(String(30), default="patient_reported", nullable=False)
    source_record_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)

    ai_extracted: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    ai_confidence: Mapped[float | None] = mapped_column(Numeric(5, 4), nullable=True)
    ai_correction_flag: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    ai_correction_note: Mapped[str | None] = mapped_column(EncryptedString, nullable=True)

    __table_args__ = (
        Index("idx_conditions_user_id", "user_id"),
        Index("idx_conditions_icd11", "icd11_code"),
        Index("idx_conditions_snomed", "snomed_code"),
        Index("idx_conditions_user_status", "user_id", "clinical_status"),
        Index("idx_conditions_source_record", "source_record_id"),
    )


class Medication(Base):
    __tablename__ = "medications"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )

    name: Mapped[str] = mapped_column(String(255), nullable=False)
    generic_name: Mapped[str | None] = mapped_column(String(255), nullable=True)
    brand_name: Mapped[str | None] = mapped_column(String(255), nullable=True)

    atc_code: Mapped[str | None] = mapped_column(String(7), nullable=True)
    atc_display: Mapped[str | None] = mapped_column(String(255), nullable=True)

    snomed_code: Mapped[str | None] = mapped_column(String(50), nullable=True)
    snomed_display: Mapped[str | None] = mapped_column(String(255), nullable=True)

    dosage_form: Mapped[str | None] = mapped_column(String(50), nullable=True)
    strength: Mapped[str | None] = mapped_column(String(100), nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    __table_args__ = (
        Index("idx_medications_name", "name"),
        Index("idx_medications_atc_code", "atc_code"),
        Index("idx_medications_generic_name", "generic_name"),
    )


class MedicationRequest(Base, AuditMixin, SoftDeleteMixin):
    __tablename__ = "medication_requests"

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
    medication_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("medications.id", ondelete="SET NULL"),
        nullable=True,
    )

    fhir_resource_id: Mapped[str | None] = mapped_column(String(255), nullable=True)

    medication_name_raw: Mapped[str] = mapped_column(EncryptedString, nullable=False)
    dosage_instruction: Mapped[str | None] = mapped_column(EncryptedString, nullable=True)
    dose_quantity: Mapped[str | None] = mapped_column(String(100), nullable=True)
    dose_frequency: Mapped[str | None] = mapped_column(String(100), nullable=True)
    route: Mapped[str | None] = mapped_column(String(50), nullable=True)

    status: Mapped[str] = mapped_column(String(20), default="active", nullable=False)
    intent: Mapped[str] = mapped_column(String(30), default="order", nullable=False)

    prescribing_doctor: Mapped[str | None] = mapped_column(EncryptedString, nullable=True)
    prescribed_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    start_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    end_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    duration_days: Mapped[int | None] = mapped_column(Integer, nullable=True)

    source_record_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    encounter_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("encounters.id", ondelete="SET NULL"),
        nullable=True,
    )

    ai_extracted: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    ai_confidence: Mapped[float | None] = mapped_column(Numeric(5, 4), nullable=True)
    ai_correction_flag: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    ai_correction_note: Mapped[str | None] = mapped_column(EncryptedString, nullable=True)

    __table_args__ = (
        Index("idx_med_requests_user_id", "user_id"),
        Index("idx_med_requests_user_status", "user_id", "status"),
        Index("idx_med_requests_source_record", "source_record_id"),
        Index("idx_med_requests_medication_id", "medication_id"),
    )


class Observation(Base, AuditMixin, SoftDeleteMixin):
    __tablename__ = "observations"

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

    fhir_resource_id: Mapped[str | None] = mapped_column(String(255), nullable=True)

    loinc_code: Mapped[str | None] = mapped_column(String(20), nullable=True)
    loinc_display: Mapped[str | None] = mapped_column(EncryptedString, nullable=True)

    observation_category: Mapped[str] = mapped_column(String(30), nullable=False)
    observation_name: Mapped[str] = mapped_column(EncryptedString, nullable=False)

    status: Mapped[str] = mapped_column(String(30), default="final", nullable=False)

    value_quantity: Mapped[float | None] = mapped_column(Numeric(12, 4), nullable=True)
    value_unit: Mapped[str | None] = mapped_column(String(50), nullable=True)
    value_string: Mapped[str | None] = mapped_column(EncryptedString, nullable=True)
    value_boolean: Mapped[bool | None] = mapped_column(Boolean, nullable=True)

    reference_range_low: Mapped[float | None] = mapped_column(Numeric(12, 4), nullable=True)
    reference_range_high: Mapped[float | None] = mapped_column(Numeric(12, 4), nullable=True)
    interpretation: Mapped[str | None] = mapped_column(String(20), nullable=True)

    effective_datetime: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    issued_datetime: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    body_site: Mapped[str | None] = mapped_column(EncryptedString, nullable=True)

    source_record_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    encounter_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("encounters.id", ondelete="SET NULL"),
        nullable=True,
    )

    ai_extracted: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    ai_confidence: Mapped[float | None] = mapped_column(Numeric(5, 4), nullable=True)
    ai_correction_flag: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    ai_correction_note: Mapped[str | None] = mapped_column(EncryptedString, nullable=True)

    components: Mapped[list["ObservationComponent"]] = relationship(
        "ObservationComponent", back_populates="observation"
    )

    __table_args__ = (
        Index("idx_observations_user_id", "user_id"),
        Index("idx_observations_loinc", "loinc_code"),
        Index("idx_observations_user_category", "user_id", "observation_category"),
        Index("idx_observations_effective_dt", "effective_datetime"),
        Index("idx_observations_source_record", "source_record_id"),
        Index("idx_observations_trend_query", "user_id", "loinc_code", "effective_datetime"),
    )


class ObservationComponent(Base):
    __tablename__ = "observation_components"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    observation_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("observations.id", ondelete="CASCADE"),
        nullable=False,
    )

    loinc_code: Mapped[str | None] = mapped_column(String(20), nullable=True)
    loinc_display: Mapped[str | None] = mapped_column(EncryptedString, nullable=True)
    component_name: Mapped[str] = mapped_column(EncryptedString, nullable=False)

    value_quantity: Mapped[float | None] = mapped_column(Numeric(12, 4), nullable=True)
    value_unit: Mapped[str | None] = mapped_column(String(50), nullable=True)
    value_string: Mapped[str | None] = mapped_column(EncryptedString, nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    observation: Mapped["Observation"] = relationship("Observation", back_populates="components")

    __table_args__ = (
        Index("idx_obs_components_observation_id", "observation_id"),
    )


class Encounter(Base, AuditMixin, SoftDeleteMixin):
    __tablename__ = "encounters"

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

    fhir_resource_id: Mapped[str | None] = mapped_column(String(255), nullable=True)

    encounter_type: Mapped[str] = mapped_column(String(30), nullable=False)
    status: Mapped[str] = mapped_column(String(20), default="finished", nullable=False)

    title: Mapped[str] = mapped_column(EncryptedString, nullable=False)
    description: Mapped[str | None] = mapped_column(EncryptedString, nullable=True)

    practitioner_name: Mapped[str | None] = mapped_column(EncryptedString, nullable=True)
    practitioner_specialty: Mapped[str | None] = mapped_column(EncryptedString, nullable=True)
    organization_name: Mapped[str | None] = mapped_column(EncryptedString, nullable=True)

    start_datetime: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    end_datetime: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    batch_number: Mapped[str | None] = mapped_column(String(100), nullable=True)

    source_record_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)

    ai_extracted: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    ai_confidence: Mapped[float | None] = mapped_column(Numeric(5, 4), nullable=True)
    ai_correction_flag: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    ai_correction_note: Mapped[str | None] = mapped_column(EncryptedString, nullable=True)

    __table_args__ = (
        Index("idx_encounters_user_id", "user_id"),
        Index("idx_encounters_user_type", "user_id", "encounter_type"),
        Index("idx_encounters_start_dt", "start_datetime"),
        Index("idx_encounters_source_record", "source_record_id"),
    )
