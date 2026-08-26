"""add ai_analysis column to medical_records

Revision ID: a1b2c3d4e5f6
Revises: f0163c91ed1d
Create Date: 2026-06-29 14:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSONB

revision: str = 'a1b2c3d4e5f6'
down_revision: Union[str, None] = 'f0163c91ed1d'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        'medical_records',
        sa.Column('ai_analysis', JSONB, nullable=True),
    )


def downgrade() -> None:
    op.drop_column('medical_records', 'ai_analysis')
