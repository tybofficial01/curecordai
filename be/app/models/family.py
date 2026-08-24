import uuid
from datetime import date, datetime

from sqlalchemy import Boolean, Date, DateTime, ForeignKey, Index, Integer, String, func, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.encryption import EncryptedString
from app.database import Base
from app.models.base import AuditMixin, SoftDeleteMixin


class FamilyMember(Base, AuditMixin, SoftDeleteMixin):
    __tablename__ = "family_members"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    owner_user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )

    fhir_patient_id: Mapped[str | None] = mapped_column(String(255), unique=True, nullable=True)

    full_name: Mapped[str] = mapped_column(EncryptedString, nullable=False)
    date_of_birth: Mapped[date | None] = mapped_column(Date, nullable=True)
    age: Mapped[int | None] = mapped_column(Integer, nullable=True)
    gender: Mapped[str | None] = mapped_column(String(20), nullable=True)
    blood_group: Mapped[str | None] = mapped_column(String(10), nullable=True)

    relationship: Mapped[str] = mapped_column(String(50), nullable=False)
    role: Mapped[str] = mapped_column(String(20), nullable=False)
    access_level: Mapped[str] = mapped_column(String(30), default="full", nullable=False)

    photo_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    photo_key: Mapped[str | None] = mapped_column(String(255), nullable=True)

    __table_args__ = (
        Index("idx_family_owner_user_id", "owner_user_id"),
        Index("idx_family_owner_active", "owner_user_id", "is_deleted"),
        Index("idx_family_fhir_patient_id", "fhir_patient_id"),
    )
