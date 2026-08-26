"""Add per-account login lockout columns to users (SECURITY_AUDIT.md H9)

Revision ID: a3f9c1d2e4b6
Revises: f2b3c4d5e6a7
Create Date: 2026-08-08 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = 'a3f9c1d2e4b6'
down_revision: Union[str, None] = 'f2b3c4d5e6a7'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        'users',
        sa.Column('failed_login_attempts', sa.Integer(), server_default='0', nullable=False),
    )
    op.add_column(
        'users',
        sa.Column('locked_until', sa.DateTime(timezone=True), nullable=True),
    )


def downgrade() -> None:
    op.drop_column('users', 'locked_until')
    op.drop_column('users', 'failed_login_attempts')
