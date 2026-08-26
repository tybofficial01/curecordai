"""add privacy columns to app_settings

Revision ID: c7d9e2f1a3b8
Revises: f0163c91ed1d
Create Date: 2026-07-04 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'c7d9e2f1a3b8'
down_revision: Union[str, None] = 'f0163c91ed1d'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('app_settings', sa.Column('app_lock_on_background', sa.Boolean(), nullable=False, server_default=sa.false()))
    op.add_column('app_settings', sa.Column('screenshot_prevention', sa.Boolean(), nullable=False, server_default=sa.false()))


def downgrade() -> None:
    op.drop_column('app_settings', 'screenshot_prevention')
    op.drop_column('app_settings', 'app_lock_on_background')
