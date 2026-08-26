"""add extracted_text column to medical_records

Revision ID: d4e8f2a61b95
Revises: c92a4e1f7b03
Create Date: 2026-07-03 09:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = 'd4e8f2a61b95'
down_revision: Union[str, None] = 'c92a4e1f7b03'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('medical_records', sa.Column('extracted_text', sa.Text(), nullable=True))


def downgrade() -> None:
    op.drop_column('medical_records', 'extracted_text')
