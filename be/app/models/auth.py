import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Index, Integer, String, Text, func, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models.base import TimestampMixin


class User(Base, TimestampMixin):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )

    # Auth identifiers
    phone_number: Mapped[str | None] = mapped_column(String(20), unique=True, nullable=True)
    email: Mapped[str | None] = mapped_column(String(255), unique=True, nullable=True)
    password_hash: Mapped[str | None] = mapped_column(String(255), nullable=True)

    # Auth provider
    auth_provider: Mapped[str] = mapped_column(String(20), default="phone", nullable=False)
    oauth_provider_id: Mapped[str | None] = mapped_column(String(255), nullable=True)

    # Account state
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    is_email_verified: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_phone_verified: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    # MFA
    mfa_enabled: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    # Data residency
    data_region: Mapped[str] = mapped_column(String(10), default="PK", nullable=False)

    # FHIR R4 Patient link
    fhir_patient_id: Mapped[str | None] = mapped_column(String(255), unique=True, nullable=True)

    # Soft delete + GDPR
    is_deleted: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    deleted_by_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    deletion_reason: Mapped[str | None] = mapped_column(String(50), nullable=True)
    scheduled_purge_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    last_login_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    # Account lockout - independent of source IP (see SECURITY_AUDIT.md H9)
    failed_login_attempts: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    locked_until: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    # Relationships
    profile: Mapped["UserProfile"] = relationship("UserProfile", back_populates="user", uselist=False)
    setting: Mapped["AppSetting | None"] = relationship("AppSetting", back_populates="user", uselist=False)
    sessions: Mapped[list["UserSession"]] = relationship("UserSession", back_populates="user")
    otp_requests: Mapped[list["UserOtpRequest"]] = relationship("UserOtpRequest", back_populates="user")
    push_tokens: Mapped[list["PushNotificationToken"]] = relationship("PushNotificationToken", back_populates="user")
    user_roles: Mapped[list["UserRole"]] = relationship("UserRole", foreign_keys="UserRole.user_id", back_populates="user")

    __table_args__ = (
        Index("idx_users_phone", "phone_number"),
        Index("idx_users_email", "email"),
        Index("idx_users_is_deleted", "is_deleted"),
        Index("idx_users_data_region", "data_region"),
        Index("idx_users_fhir_patient_id", "fhir_patient_id"),
    )


class UserOtpRequest(Base):
    __tablename__ = "user_otp_requests"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )

    channel: Mapped[str] = mapped_column(String(10), nullable=False)
    recipient: Mapped[str] = mapped_column(String(255), nullable=False)
    otp_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    purpose: Mapped[str] = mapped_column(String(30), nullable=False)

    is_used: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    attempt_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    max_attempts: Mapped[int] = mapped_column(Integer, default=5, nullable=False)

    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    used_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    ip_address: Mapped[str | None] = mapped_column(String(45), nullable=True)
    user_agent: Mapped[str | None] = mapped_column(Text, nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    user: Mapped["User | None"] = relationship("User", back_populates="otp_requests", foreign_keys=[user_id])

    __table_args__ = (
        Index("idx_otp_recipient_purpose", "recipient", "purpose"),
        Index("idx_otp_expires_at", "expires_at"),
    )


class UserSession(Base):
    __tablename__ = "user_sessions"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )

    session_token_hash: Mapped[str] = mapped_column(String(255), unique=True, nullable=False)
    refresh_token_hash: Mapped[str | None] = mapped_column(String(255), unique=True, nullable=True)

    device_type: Mapped[str | None] = mapped_column(String(20), nullable=True)
    device_id: Mapped[str | None] = mapped_column(String(255), nullable=True)
    device_name: Mapped[str | None] = mapped_column(String(255), nullable=True)

    ip_address: Mapped[str | None] = mapped_column(String(45), nullable=True)
    user_agent: Mapped[str | None] = mapped_column(Text, nullable=True)

    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    last_activity_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    revoke_reason: Mapped[str | None] = mapped_column(String(50), nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    user: Mapped["User"] = relationship("User", back_populates="sessions", foreign_keys=[user_id])

    __table_args__ = (
        Index("idx_sessions_user_id", "user_id"),
        Index("idx_sessions_token_hash", "session_token_hash"),
        Index("idx_sessions_user_active", "user_id", "is_active"),
        Index("idx_sessions_expires_at", "expires_at"),
    )


class PushNotificationToken(Base):
    __tablename__ = "push_notification_tokens"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )

    token: Mapped[str] = mapped_column(String(500), nullable=False)
    platform: Mapped[str] = mapped_column(String(10), nullable=False)
    device_id: Mapped[str | None] = mapped_column(String(255), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    user: Mapped["User"] = relationship("User", back_populates="push_tokens", foreign_keys=[user_id])

    __table_args__ = (
        Index("idx_push_tokens_user_id", "user_id"),
        Index("idx_push_tokens_user_platform", "user_id", "platform"),
    )


# Avoid circular import - import here after defining User
from app.models.profile import UserProfile  # noqa: E402
from app.models.rbac import UserRole  # noqa: E402
from app.models.settings import AppSetting  # noqa: E402
