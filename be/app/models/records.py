import uuid
from datetime import date, datetime

from pgvector.sqlalchemy import Vector
from sqlalchemy import BigInteger, Boolean, Date, DateTime, ForeignKey, Index, Integer, String, Text, func, text
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.config import settings
from app.core.encryption import EncryptedString
from app.database import Base
from app.models.base import AuditMixin, SoftDeleteMixin


class RecordFolder(Base, AuditMixin, SoftDeleteMixin):
    __tablename__ = "record_folders"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )

    name: Mapped[str] = mapped_column(String(100), nullable=False)
    icon: Mapped[str | None] = mapped_column(String(50), nullable=True)
    sort_order: Mapped[int] = mapped_column(Integer, default=0, nullable=False)

    records: Mapped[list["MedicalRecord"]] = relationship("MedicalRecord", back_populates="folder")

    __table_args__ = (
        Index("idx_record_folders_user_id", "user_id"),
        Index("idx_record_folders_user_active", "user_id", "is_deleted"),
    )


class MedicalRecord(Base, AuditMixin, SoftDeleteMixin):
    __tablename__ = "medical_records"

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
    folder_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("record_folders.id", ondelete="SET NULL"),
        nullable=True,
    )

    fhir_resource_id: Mapped[str | None] = mapped_column(String(255), nullable=True)

    title: Mapped[str] = mapped_column(EncryptedString, nullable=False)
    record_type: Mapped[str] = mapped_column(String(30), nullable=False)
    record_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    # Date printed on the document itself, as extracted by the AI pipeline (finalize step of
    # process_record.py). Distinct from record_date, which is user-supplied at upload time.
    # NULL means unknown — never assume a NULL document is recent.
    document_date: Mapped[date | None] = mapped_column(Date, nullable=True)

    # Secure file storage - S3 keys only, never raw URLs
    file_key: Mapped[str] = mapped_column(String(500), nullable=False)
    file_name: Mapped[str] = mapped_column(String(255), nullable=False)
    file_mime_type: Mapped[str] = mapped_column(String(100), nullable=False)
    file_size_bytes: Mapped[int] = mapped_column(BigInteger, nullable=False)
    file_hash: Mapped[str | None] = mapped_column(String(64), nullable=True)

    patient_name_on_doc: Mapped[str | None] = mapped_column(EncryptedString, nullable=True)
    laboratory_name: Mapped[str | None] = mapped_column(EncryptedString, nullable=True)
    referring_doctor: Mapped[str | None] = mapped_column(EncryptedString, nullable=True)
    issuing_organization: Mapped[str | None] = mapped_column(EncryptedString, nullable=True)

    processing_status: Mapped[str] = mapped_column(String(20), default="pending", nullable=False)
    processing_error: Mapped[str | None] = mapped_column(Text, nullable=True)

    # Text content the pipeline extracted from the file (PDF text layer / docx / plain text /
    # Vision LLM rendering for images). Persisted so re-summarizing, re-embedding, or re-running
    # extraction with an improved prompt never needs to re-touch S3 or re-pay for Vision LLM.
    extracted_text: Mapped[str | None] = mapped_column(EncryptedString, nullable=True)

    ai_summary: Mapped[str | None] = mapped_column(EncryptedString, nullable=True)
    ai_summary_generated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    ai_summary_model_version: Mapped[str | None] = mapped_column(String(50), nullable=True)
    ai_analysis: Mapped[dict | None] = mapped_column(JSONB, nullable=True)

    # DICOM support
    is_dicom: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    dicom_study_instance_uid: Mapped[str | None] = mapped_column(String(255), nullable=True)
    dicom_series_instance_uid: Mapped[str | None] = mapped_column(String(255), nullable=True)
    dicom_sop_class_uid: Mapped[str | None] = mapped_column(String(255), nullable=True)

    deletion_type: Mapped[str | None] = mapped_column(String(20), nullable=True)

    uploaded_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    folder: Mapped["RecordFolder | None"] = relationship("RecordFolder", back_populates="records")

    __table_args__ = (
        Index("idx_medical_records_user_id", "user_id"),
        Index("idx_medical_records_user_type", "user_id", "record_type"),
        Index("idx_medical_records_user_active", "user_id", "is_deleted"),
        Index("idx_medical_records_folder_id", "folder_id"),
        Index("idx_medical_records_date", "record_date"),
        Index("idx_medical_records_document_date", "document_date"),
        Index("idx_medical_records_processing_status", "processing_status"),
        Index("idx_medical_records_family_member_id", "family_member_id"),
    )


class RecordChunk(Base):
    """
    Chunked + embedded document text for RAG-based AI chat retrieval.
    Populated by the ingestion pipeline (process_record.py) after content extraction.
    Denormalizes user_id/family_member_id from MedicalRecord for scoped similarity search
    without a join on the hot retrieval path.
    """
    __tablename__ = "record_chunks"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    record_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("medical_records.id", ondelete="CASCADE"),
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

    chunk_index: Mapped[int] = mapped_column(Integer, nullable=False)
    chunk_text: Mapped[str] = mapped_column(EncryptedString, nullable=False)
    embedding: Mapped[list[float]] = mapped_column(Vector(settings.AI_EMBEDDING_DIMENSIONS), nullable=False)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    __table_args__ = (
        Index("idx_record_chunks_record_id", "record_id"),
        Index("idx_record_chunks_user_family", "user_id", "family_member_id"),
    )
