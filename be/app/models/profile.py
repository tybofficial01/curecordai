import uuid
from datetime import date, datetime

from sqlalchemy import Boolean, Date, DateTime, ForeignKey, Index, Integer, Numeric, String, func, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.encryption import EncryptedString
from app.database import Base
from app.models.base import AuditMixin, SoftDeleteMixin


class UserProfile(Base, AuditMixin, SoftDeleteMixin):
    __tablename__ = "user_profiles"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
    )

    patient_id_display: Mapped[str | None] = mapped_column(String(20), unique=True, nullable=True)

    full_name: Mapped[str] = mapped_column(EncryptedString, nullable=False)
    date_of_birth: Mapped[date | None] = mapped_column(Date, nullable=True)
    gender: Mapped[str | None] = mapped_column(String(20), nullable=True)

    height_cm: Mapped[float | None] = mapped_column(Numeric(5, 2), nullable=True)
    weight_kg: Mapped[float | None] = mapped_column(Numeric(5, 2), nullable=True)
    blood_group: Mapped[str | None] = mapped_column(String(10), nullable=True)
    bmi: Mapped[float | None] = mapped_column(Numeric(4, 2), nullable=True)

    profile_photo_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    profile_photo_key: Mapped[str | None] = mapped_column(String(255), nullable=True)

    profile_completion_pct: Mapped[int] = mapped_column(Integer, default=0, nullable=False)

    user: Mapped["User"] = relationship("User", back_populates="profile", foreign_keys=[user_id])

    __table_args__ = (
        Index("idx_user_profiles_user_id", "user_id"),
        Index("idx_user_profiles_patient_display_id", "patient_id_display"),
    )


from app.models.auth import User  # noqa: E402
