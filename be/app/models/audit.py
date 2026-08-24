import uuid
from datetime import datetime

from sqlalchemy import DateTime, Index, Integer, String, Text, func, text
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class AuditLog(Base):
    """
    IMMUTABLE. Never UPDATE or DELETE. Append-only / WORM.
    Stored in the 'audit' schema (separate from app data per HIPAA §164.312).
    No PHI stored - opaque resource IDs only.
    Minimum 6-year retention per HIPAA §164.312(b).
    """
    __tablename__ = "audit_logs"
    __table_args__ = (
        Index("idx_audit_actor_user", "actor_user_id"),
        Index("idx_audit_resource_owner", "resource_owner_user_id"),
        Index("idx_audit_resource", "resource_type", "resource_id"),
        Index("idx_audit_created_at", "created_at"),
        Index("idx_audit_action", "action"),
        Index("idx_audit_actor_timeline", "actor_user_id", "created_at"),
        Index("idx_audit_owner_timeline", "resource_owner_user_id", "created_at"),
        {"schema": "audit"},
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )

    actor_user_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    actor_role_snapshot: Mapped[str | None] = mapped_column(String(50), nullable=True)
    actor_ip: Mapped[str | None] = mapped_column(String(45), nullable=True)
    actor_device_type: Mapped[str | None] = mapped_column(String(20), nullable=True)
    actor_user_agent: Mapped[str | None] = mapped_column(Text, nullable=True)

    action: Mapped[str] = mapped_column(String(50), nullable=False)

    resource_type: Mapped[str] = mapped_column(String(50), nullable=False)
    resource_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    resource_owner_user_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)

    http_method: Mapped[str | None] = mapped_column(String(10), nullable=True)
    endpoint: Mapped[str | None] = mapped_column(String(255), nullable=True)
    request_id: Mapped[str | None] = mapped_column(String(100), nullable=True)

    outcome_status: Mapped[str] = mapped_column(String(20), nullable=False)
    http_status_code: Mapped[int | None] = mapped_column(Integer, nullable=True)
    error_message: Mapped[str | None] = mapped_column(Text, nullable=True)

    access_purpose: Mapped[str | None] = mapped_column(String(30), nullable=True)
    break_glass_reason: Mapped[str | None] = mapped_column(Text, nullable=True)

    additional_context: Mapped[dict | None] = mapped_column(JSONB, nullable=True)

    hash_chain_value: Mapped[str | None] = mapped_column(String(64), nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
