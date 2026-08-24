import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Index, Integer, String, Text, func, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class SecurityIncident(Base):
    __tablename__ = "security_incidents"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )

    incident_type: Mapped[str] = mapped_column(String(50), nullable=False)
    severity: Mapped[str] = mapped_column(String(20), nullable=False)
    status: Mapped[str] = mapped_column(String(20), default="open", nullable=False)

    description: Mapped[str] = mapped_column(Text, nullable=False)

    affected_user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    affected_user_count: Mapped[int | None] = mapped_column(Integer, nullable=True)
    affected_data_types: Mapped[str | None] = mapped_column(Text, nullable=True)

    discovered_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    notified_users_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    notified_regulator_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    resolved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    remediation_notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    post_mortem_url: Mapped[str | None] = mapped_column(String(500), nullable=True)

    reported_by_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    __table_args__ = (
        Index("idx_incidents_severity", "severity"),
        Index("idx_incidents_status", "status"),
        Index("idx_incidents_affected_user", "affected_user_id"),
        Index("idx_incidents_discovered_at", "discovered_at"),
    )
