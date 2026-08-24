import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Index, String, Text, func, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class FhirResourceMapping(Base):
    __tablename__ = "fhir_resource_mappings"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )

    internal_resource_type: Mapped[str] = mapped_column(String(50), nullable=False)
    internal_resource_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)

    fhir_resource_type: Mapped[str] = mapped_column(String(50), nullable=False)
    fhir_resource_id: Mapped[str] = mapped_column(String(255), nullable=False)
    fhir_server_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    fhir_version: Mapped[str] = mapped_column(String(10), default="R4", nullable=False)

    source_system: Mapped[str | None] = mapped_column(String(100), nullable=True)
    source_system_id: Mapped[str | None] = mapped_column(String(255), nullable=True)

    last_synced_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    sync_status: Mapped[str | None] = mapped_column(String(20), nullable=True)
    sync_error_message: Mapped[str | None] = mapped_column(Text, nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    __table_args__ = (
        Index("idx_fhir_mapping_internal_unique", "internal_resource_type", "internal_resource_id", unique=True),
        Index("idx_fhir_mapping_fhir_resource", "fhir_resource_type", "fhir_resource_id"),
        Index("idx_fhir_mapping_source_system", "source_system"),
        Index("idx_fhir_mapping_sync_status", "sync_status"),
    )


class IntegrationToken(Base):
    __tablename__ = "integration_tokens"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )

    provider: Mapped[str] = mapped_column(String(50), nullable=False)
    provider_type: Mapped[str] = mapped_column(String(20), nullable=False)

    access_token_encrypted: Mapped[str | None] = mapped_column(Text, nullable=True)
    refresh_token_encrypted: Mapped[str | None] = mapped_column(Text, nullable=True)
    token_type: Mapped[str | None] = mapped_column(String(20), nullable=True)
    scope: Mapped[str | None] = mapped_column(Text, nullable=True)

    token_expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    revoke_reason: Mapped[str | None] = mapped_column(String(50), nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    __table_args__ = (
        Index("idx_integration_tokens_user_id", "user_id"),
        Index("idx_integration_tokens_user_provider", "user_id", "provider", unique=True),
        Index("idx_integration_tokens_active_expiry", "is_active", "token_expires_at"),
    )
