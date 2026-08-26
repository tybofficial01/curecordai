"""Add document_date column to medical_records

Revision ID: c3d5e7f9a1b4
Revises: b1c8e4a2f9d7
Create Date: 2026-08-17 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = 'c3d5e7f9a1b4'
down_revision: Union[str, None] = 'b1c8e4a2f9d7'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Nullable, no server_default — existing rows backfill as NULL ("unknown age"),
    # never a guessed date. Distinct from record_date (user-supplied at upload time):
    # document_date is the date printed on the document itself, extracted by the AI pipeline.
    op.add_column('medical_records', sa.Column('document_date', sa.Date(), nullable=True))
    op.create_index('idx_medical_records_document_date', 'medical_records', ['document_date'], unique=False)


def downgrade() -> None:
    op.drop_index('idx_medical_records_document_date', table_name='medical_records')
    op.drop_column('medical_records', 'document_date')
