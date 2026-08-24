import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, String, func, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class AppSetting(Base):
    __tablename__ = "app_settings"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
    )

    language: Mapped[str] = mapped_column(String(10), default="en", nullable=False)
    theme: Mapped[str] = mapped_column(String(10), default="light", nullable=False)

    biometric_lock_enabled: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    app_lock_on_background: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    screenshot_prevention: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    push_notifications_enabled: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    email_notifications_enabled: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    drug_interaction_alerts: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    lab_result_alerts: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    vital_threshold_alerts: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    # GDPR: opt-in required, default false
    analytics_opt_in: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    user: Mapped["User"] = relationship("User", back_populates="setting", foreign_keys=[user_id])
