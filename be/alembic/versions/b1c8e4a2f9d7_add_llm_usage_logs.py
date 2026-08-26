"""Add llm_usage_logs table for LLM cost tracking

Revision ID: b1c8e4a2f9d7
Revises: a9c1e3f5b7d2
Create Date: 2026-08-14 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = 'b1c8e4a2f9d7'
down_revision: Union[str, None] = 'a9c1e3f5b7d2'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'llm_usage_logs',
        sa.Column('id', postgresql.UUID(as_uuid=True), server_default=sa.text('gen_random_uuid()'), nullable=False),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column('family_member_id', postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column('feature', sa.String(length=50), nullable=False),
        sa.Column('provider', sa.String(length=30), nullable=False, server_default='openrouter'),
        sa.Column('model', sa.String(length=150), nullable=False),
        sa.Column('prompt_tokens', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('completion_tokens', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('total_tokens', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('cost_usd', sa.Numeric(precision=12, scale=6), nullable=True),
        sa.Column('status', sa.String(length=20), nullable=False, server_default='success'),
        sa.Column('error_message', sa.Text(), nullable=True),
        sa.Column('duration_ms', sa.Integer(), nullable=True),
        sa.Column('request_id', sa.String(length=100), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='SET NULL'),
        sa.ForeignKeyConstraint(['family_member_id'], ['family_members.id'], ondelete='SET NULL'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('idx_llm_usage_user_id', 'llm_usage_logs', ['user_id'])
    op.create_index('idx_llm_usage_feature', 'llm_usage_logs', ['feature'])
    op.create_index('idx_llm_usage_created_at', 'llm_usage_logs', ['created_at'])
    op.create_index('idx_llm_usage_user_created', 'llm_usage_logs', ['user_id', 'created_at'])


def downgrade() -> None:
    op.drop_index('idx_llm_usage_user_created', table_name='llm_usage_logs')
    op.drop_index('idx_llm_usage_created_at', table_name='llm_usage_logs')
    op.drop_index('idx_llm_usage_feature', table_name='llm_usage_logs')
    op.drop_index('idx_llm_usage_user_id', table_name='llm_usage_logs')
    op.drop_table('llm_usage_logs')
