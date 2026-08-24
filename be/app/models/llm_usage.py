import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Index, Integer, Numeric, String, Text, func, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class LlmUsageLog(Base):
    """
    One row per LLM request made through app.services.openrouter, regardless of call site.
    Cost is taken directly from OpenRouter's per-request usage accounting (see
    app/services/llm_cost_tracker.py) rather than computed from a locally-maintained price
    table, so it stays correct as OpenRouter's own pricing changes.
    Rows are written asynchronously (fire-and-forget) so a slow/failed insert here never
    delays or breaks the LLM call it's recording.
    """
    __tablename__ = "llm_usage_logs"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )

    # Who/what this call was made on behalf of. Nullable - some calls (e.g. system-level
    # background jobs) have no single owning user; never block the log write on this.
    user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    family_member_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("family_members.id", ondelete="SET NULL"), nullable=True
    )

    # Logical call site, e.g. "chat", "chat_title", "chat_history_summary", "extraction_text",
    # "extraction_image", "observation_analysis", "document_summary", "health_overview", "embedding".
    feature: Mapped[str] = mapped_column(String(50), nullable=False)
    provider: Mapped[str] = mapped_column(String(30), nullable=False, default="openrouter")
    model: Mapped[str] = mapped_column(String(150), nullable=False)

    prompt_tokens: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    completion_tokens: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    total_tokens: Mapped[int] = mapped_column(Integer, nullable=False, default=0)

    # USD cost as reported by OpenRouter's usage accounting (null when the provider didn't
    # return a cost for this call, e.g. embeddings on some models).
    cost_usd: Mapped[Numeric | None] = mapped_column(Numeric(12, 6), nullable=True)

    status: Mapped[str] = mapped_column(String(20), nullable=False, default="success")
    error_message: Mapped[str | None] = mapped_column(Text, nullable=True)

    duration_ms: Mapped[int | None] = mapped_column(Integer, nullable=True)
    request_id: Mapped[str | None] = mapped_column(String(100), nullable=True)  # OpenRouter's response id

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    __table_args__ = (
        Index("idx_llm_usage_user_id", "user_id"),
        Index("idx_llm_usage_feature", "feature"),
        Index("idx_llm_usage_created_at", "created_at"),
        Index("idx_llm_usage_user_created", "user_id", "created_at"),
    )
