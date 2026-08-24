"""
WhatsApp channel state: inbound message dedupe/audit, and the confirmed number-to-account
binding gate. See core.scoping / ai_chat.py for the family_scope pattern these plug into -
a WhatsApp number resolves to a User exactly like a bearer token does, then every downstream
query goes through the same ownership checks as the web/mobile routers.
"""
import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Index, Integer, String, Text, func, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class WhatsAppInboundMessage(Base):
    """
    Dedupe + audit trail for inbound webhook events. Meta retries a webhook POST that doesn't
    get a fast 200, so without this table the same document could get uploaded twice or the
    same chat message answered twice. `status` transitions drive the reconciliation worker
    (tasks/whatsapp_reconciliation_worker.py), which retries anything stuck in "processing".
    """
    __tablename__ = "whatsapp_inbound_messages"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    wa_message_id: Mapped[str] = mapped_column(String(128), unique=True, nullable=False)
    # Null when the sender never resolved to a registered/confirmed user - still recorded for
    # audit (e.g. onboarding-nudge volume) but carries no record/chat access implications.
    user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    sender_wa_number: Mapped[str] = mapped_column(String(20), nullable=False)
    message_type: Mapped[str] = mapped_column(String(20), nullable=False)  # text|image|document|audio|interactive
    direction: Mapped[str] = mapped_column(String(10), default="inbound", nullable=False)
    status: Mapped[str] = mapped_column(String(20), default="received", nullable=False)
    # received -> processing -> completed|failed. Reconciliation worker retries rows stuck in
    # "processing" past a threshold, then marks "failed" and notifies the user after one retry.
    retry_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    error_message: Mapped[str | None] = mapped_column(Text, nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    __table_args__ = (
        Index("idx_wa_inbound_wa_message_id", "wa_message_id"),
        Index("idx_wa_inbound_status", "status"),
        Index("idx_wa_inbound_user_id", "user_id"),
    )


class WhatsAppBinding(Base):
    """
    The actual access gate: separates "this number matches a verified phone on file" (cheap,
    spoofable at the telecom layer - see number recycling) from "this number has been explicitly
    confirmed via a second, already-trusted channel". The webhook handler checks this table,
    not just User.phone_number, before unlocking any record/chat tool.

    `active_session_id` is the WhatsApp conversation's "active profile" pointer - which patient
    (self or a family member) the next unqualified message is about - reusing AiChatSession's
    existing per-patient scoping rather than adding a second concept of "current profile".
    """
    __tablename__ = "whatsapp_bindings"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    wa_phone_number: Mapped[str] = mapped_column(String(20), nullable=False)  # E.164, normalized

    confirmed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    confirmation_method: Mapped[str | None] = mapped_column(String(30), nullable=True)  # app_push_code|email_link

    # Set while a confirmation challenge is outstanding; cleared once confirmed or expired.
    pending_code_hash: Mapped[str | None] = mapped_column(String(255), nullable=True)
    pending_code_expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    active_session_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("ai_chat_sessions.id", ondelete="SET NULL"), nullable=True
    )

    # Set if this binding is later superseded by a re-confirmation (number change/rebind) -
    # kept for audit rather than deleted, never matched against for access.
    superseded_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    __table_args__ = (
        Index("idx_wa_binding_number_active", "wa_phone_number", "superseded_at"),
        Index("idx_wa_binding_user_id", "user_id"),
    )

    @property
    def is_confirmed(self) -> bool:
        return self.confirmed_at is not None and self.superseded_at is None
