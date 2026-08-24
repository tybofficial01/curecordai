import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Index, Integer, String, Text, func, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.encryption import EncryptedString
from app.database import Base


class AiChatSession(Base):
    __tablename__ = "ai_chat_sessions"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    # Which patient this session is about: null = the account owner, set = a linked family member.
    # Fixed for the lifetime of the session so every message in it is scoped consistently.
    family_member_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("family_members.id", ondelete="SET NULL"),
        nullable=True,
    )

    title: Mapped[str | None] = mapped_column(EncryptedString, nullable=True)
    status: Mapped[str] = mapped_column(String(20), default="active", nullable=False)
    # Which client this session originated from - "web" (default) or "whatsapp". Purely
    # informational (grouping/analytics); scoping/access rules are identical across channels.
    channel: Mapped[str] = mapped_column(String(20), default="web", nullable=False)

    total_messages: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    disclaimer_shown_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)

    # How many messages (from the start) have been folded into batch_summaries so far.
    # Always a multiple of chat_memory.KEEP_RECENT. Raw history sent to the LLM = messages
    # after this pointer (see chat_memory.py).
    history_summarized_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)

    is_pinned: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    # JSON list of {"record_id", "title", "record_type", "record_date"} shown to the patient in
    # the most recent find_documents/list_recent_documents reply (WhatsApp only), so a one-shot
    # follow-up like "1" or "2. Prescription for X" can be resolved to a record_id deterministically
    # server-side instead of relying on the LLM to carry an id it is never shown (see
    # whatsapp_agent.py's _redact_internal_ids / _match_pending_document_choice). Single-use:
    # cleared as soon as the next patient message is read, whether or not it resolves.
    pending_document_choices: Mapped[str | None] = mapped_column(Text, nullable=True)

    is_deleted: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    messages: Mapped[list["AiChatMessage"]] = relationship(
        "AiChatMessage", back_populates="session", order_by="AiChatMessage.created_at"
    )

    __table_args__ = (
        Index("idx_ai_sessions_user_id", "user_id"),
        Index("idx_ai_sessions_user_active", "user_id", "status"),
        Index("idx_ai_sessions_user_pinned", "user_id", "is_pinned"),
    )


class AiChatMessage(Base):
    __tablename__ = "ai_chat_messages"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    session_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("ai_chat_sessions.id", ondelete="CASCADE"),
        nullable=False,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )

    role: Mapped[str] = mapped_column(String(10), nullable=False)
    content: Mapped[str] = mapped_column(EncryptedString, nullable=False)

    source_record_ids: Mapped[str | None] = mapped_column(Text, nullable=True)  # JSON array - user-attached records
    grounding_record_ids: Mapped[str | None] = mapped_column(Text, nullable=True)  # JSON array - records actually used to ground the answer

    disclaimer_included: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    disclaimer_text: Mapped[str | None] = mapped_column(Text, nullable=True)
    disclaimer_language: Mapped[str | None] = mapped_column(String(10), nullable=True)

    model_version: Mapped[str | None] = mapped_column(String(50), nullable=True)
    confidence_level: Mapped[str | None] = mapped_column(String(20), nullable=True)

    flagged_for_review: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    flag_reason: Mapped[str | None] = mapped_column(EncryptedString, nullable=True)
    flagged_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    prompt_tokens: Mapped[int | None] = mapped_column(Integer, nullable=True)
    completion_tokens: Mapped[int | None] = mapped_column(Integer, nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    session: Mapped["AiChatSession"] = relationship("AiChatSession", back_populates="messages")

    __table_args__ = (
        Index("idx_ai_messages_session_id", "session_id"),
        Index("idx_ai_messages_user_id", "user_id"),
        Index("idx_ai_messages_session_timeline", "session_id", "created_at"),
        Index("idx_ai_messages_flagged", "flagged_for_review"),
    )


class AiChatHistorySummary(Base):
    """
    One independent, self-contained summary per fixed 20-message batch (see chat_memory.py).
    Batches are never merged into each other - batch N's summary only ever covers messages
    ((N-1)*20 + 1) .. (N*20). All batches for a session are read back at prompt-build time.
    """
    __tablename__ = "ai_chat_history_summaries"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    session_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("ai_chat_sessions.id", ondelete="CASCADE"),
        nullable=False,
    )
    batch_index: Mapped[int] = mapped_column(Integer, nullable=False)  # 1-based: batch 1 = messages 1-20
    summary_text: Mapped[str] = mapped_column(EncryptedString, nullable=False)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    __table_args__ = (
        Index("idx_ai_history_summaries_session_id", "session_id"),
        Index("idx_ai_history_summaries_session_batch", "session_id", "batch_index", unique=True),
    )
