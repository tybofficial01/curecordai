"""Add is_pinned to ai_chat_sessions

Revision ID: e5c7a9d3f1b2
Revises: d8a1f4c2b6e9
Create Date: 2026-08-12 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = 'e5c7a9d3f1b2'
down_revision: Union[str, None] = 'd8a1f4c2b6e9'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        'ai_chat_sessions',
        sa.Column('is_pinned', sa.Boolean(), nullable=False, server_default='false'),
    )
    op.create_index('idx_ai_sessions_user_pinned', 'ai_chat_sessions', ['user_id', 'is_pinned'])


def downgrade() -> None:
    op.drop_index('idx_ai_sessions_user_pinned', table_name='ai_chat_sessions')
    op.drop_column('ai_chat_sessions', 'is_pinned')
