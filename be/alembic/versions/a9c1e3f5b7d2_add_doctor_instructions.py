"""add doctor_instructions table

Revision ID: a9c1e3f5b7d2
Revises: e5c7a9d3f1b2
Create Date: 2026-08-12 00:00:00.000001

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'a9c1e3f5b7d2'
down_revision: Union[str, None] = 'e5c7a9d3f1b2'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'doctor_instructions',
        sa.Column('id', sa.UUID(), server_default=sa.text('gen_random_uuid()'), nullable=False),
        sa.Column('share_session_id', sa.UUID(), nullable=False),
        sa.Column('doctor_name', sa.String(length=255), nullable=False),
        sa.Column('doctor_institution', sa.String(length=255), nullable=False),
        sa.Column('instructions', sa.Text(), nullable=False),
        sa.Column('seen_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(['share_session_id'], ['doctor_share_sessions.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(
        'idx_doctor_instructions_share_session_id', 'doctor_instructions', ['share_session_id'], unique=False,
    )


def downgrade() -> None:
    op.drop_index('idx_doctor_instructions_share_session_id', table_name='doctor_instructions')
    op.drop_table('doctor_instructions')
