"""AI chat: independent per-batch history summaries (replaces single merged summary)

Revision ID: c92a4e1f7b03
Revises: b7d3f1a92c44
Create Date: 2026-07-02 15:30:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = 'c92a4e1f7b03'
down_revision: Union[str, None] = 'b7d3f1a92c44'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.drop_column('ai_chat_sessions', 'history_summary')

    op.create_table(
        'ai_chat_history_summaries',
        sa.Column('id', sa.UUID(), server_default=sa.text('gen_random_uuid()'), nullable=False),
        sa.Column('session_id', sa.UUID(), nullable=False),
        sa.Column('batch_index', sa.Integer(), nullable=False),
        sa.Column('summary_text', sa.Text(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['session_id'], ['ai_chat_sessions.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('idx_ai_history_summaries_session_id', 'ai_chat_history_summaries', ['session_id'])
    op.create_index(
        'idx_ai_history_summaries_session_batch', 'ai_chat_history_summaries',
        ['session_id', 'batch_index'], unique=True,
    )


def downgrade() -> None:
    op.drop_index('idx_ai_history_summaries_session_batch', table_name='ai_chat_history_summaries')
    op.drop_index('idx_ai_history_summaries_session_id', table_name='ai_chat_history_summaries')
    op.drop_table('ai_chat_history_summaries')

    op.add_column('ai_chat_sessions', sa.Column('history_summary', sa.Text(), nullable=True))
