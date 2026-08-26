"""AI chat RAG + memory: record_chunks (pgvector), session family scoping, history summary, grounding

Revision ID: b7d3f1a92c44
Revises: a1b2c3d4e5f6
Create Date: 2026-07-02 10:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from pgvector.sqlalchemy import Vector

revision: str = 'b7d3f1a92c44'
down_revision: Union[str, None] = 'a1b2c3d4e5f6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

EMBEDDING_DIMENSIONS = 1536


def upgrade() -> None:
    op.execute("CREATE EXTENSION IF NOT EXISTS vector")

    # ── record_chunks - chunked + embedded document text for RAG retrieval ──
    op.create_table(
        'record_chunks',
        sa.Column('id', sa.UUID(), server_default=sa.text('gen_random_uuid()'), nullable=False),
        sa.Column('record_id', sa.UUID(), nullable=False),
        sa.Column('user_id', sa.UUID(), nullable=False),
        sa.Column('family_member_id', sa.UUID(), nullable=True),
        sa.Column('chunk_index', sa.Integer(), nullable=False),
        sa.Column('chunk_text', sa.Text(), nullable=False),
        sa.Column('embedding', Vector(EMBEDDING_DIMENSIONS), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['record_id'], ['medical_records.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['family_member_id'], ['family_members.id'], ondelete='SET NULL'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('idx_record_chunks_record_id', 'record_chunks', ['record_id'])
    op.create_index('idx_record_chunks_user_family', 'record_chunks', ['user_id', 'family_member_id'])
    op.execute(
        "CREATE INDEX idx_record_chunks_embedding ON record_chunks "
        "USING hnsw (embedding vector_cosine_ops)"
    )

    # ── ai_chat_sessions - patient scoping + rolling history summary ──
    op.add_column('ai_chat_sessions', sa.Column('family_member_id', sa.UUID(), nullable=True))
    op.create_foreign_key(
        'fk_ai_chat_sessions_family_member_id', 'ai_chat_sessions',
        'family_members', ['family_member_id'], ['id'], ondelete='SET NULL',
    )
    op.add_column('ai_chat_sessions', sa.Column('history_summary', sa.Text(), nullable=True))
    op.add_column(
        'ai_chat_sessions',
        sa.Column('history_summarized_count', sa.Integer(), server_default='0', nullable=False),
    )

    # ── ai_chat_messages - traceability for what grounded the answer ──
    op.add_column('ai_chat_messages', sa.Column('grounding_record_ids', sa.Text(), nullable=True))


def downgrade() -> None:
    op.drop_column('ai_chat_messages', 'grounding_record_ids')

    op.drop_column('ai_chat_sessions', 'history_summarized_count')
    op.drop_column('ai_chat_sessions', 'history_summary')
    op.drop_constraint('fk_ai_chat_sessions_family_member_id', 'ai_chat_sessions', type_='foreignkey')
    op.drop_column('ai_chat_sessions', 'family_member_id')

    op.execute("DROP INDEX IF EXISTS idx_record_chunks_embedding")
    op.drop_index('idx_record_chunks_user_family', table_name='record_chunks')
    op.drop_index('idx_record_chunks_record_id', table_name='record_chunks')
    op.drop_table('record_chunks')
