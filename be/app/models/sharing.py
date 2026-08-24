import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Index, String, Text, func, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.encryption import EncryptedString
from app.database import Base


class DoctorShareSession(Base):
    __tablename__ = "doctor_share_sessions"

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

    qr_token_hash: Mapped[str] = mapped_column(String(255), unique=True, nullable=False)

    share_scope: Mapped[str] = mapped_column(String(30), nullable=False)

    status: Mapped[str] = mapped_column(String(20), default="active", nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    scanned_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    revoke_reason: Mapped[str | None] = mapped_column(String(50), nullable=True)

    scanned_by_name: Mapped[str | None] = mapped_column(EncryptedString, nullable=True)
    scanned_by_institution: Mapped[str | None] = mapped_column(EncryptedString, nullable=True)
    scanned_ip: Mapped[str | None] = mapped_column(String(45), nullable=True)
    scanned_user_agent: Mapped[str | None] = mapped_column(Text, nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    __table_args__ = (
        Index("idx_doctor_share_user_id", "user_id"),
        Index("idx_doctor_share_token_hash", "qr_token_hash"),
        Index("idx_doctor_share_expires_at", "expires_at"),
        Index("idx_doctor_share_status", "status"),
        Index("idx_doctor_share_family_member_id", "family_member_id"),
    )


class DoctorInstruction(Base):
    """A note a doctor leaves on a patient's shared record, surfaced back to the patient."""

    __tablename__ = "doctor_instructions"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    share_session_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("doctor_share_sessions.id", ondelete="CASCADE"),
        nullable=False,
    )

    doctor_name: Mapped[str] = mapped_column(EncryptedString, nullable=False)
    doctor_institution: Mapped[str] = mapped_column(EncryptedString, nullable=False)
    instructions: Mapped[str] = mapped_column(EncryptedString, nullable=False)

    seen_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    __table_args__ = (
        Index("idx_doctor_instructions_share_session_id", "share_session_id"),
    )


class DataSharingConsent(Base):
    __tablename__ = "data_sharing_consents"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )

    grantee_name: Mapped[str | None] = mapped_column(EncryptedString, nullable=True)
    grantee_type: Mapped[str] = mapped_column(String(20), nullable=False)
    grantee_institution: Mapped[str | None] = mapped_column(EncryptedString, nullable=True)

    access_scope: Mapped[str] = mapped_column(String(30), nullable=False)

    granted_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    revoke_reason: Mapped[str | None] = mapped_column(Text, nullable=True)

    status: Mapped[str] = mapped_column(String(20), default="active", nullable=False)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    __table_args__ = (
        Index("idx_data_sharing_user_id", "user_id"),
        Index("idx_data_sharing_user_status", "user_id", "status"),
    )
