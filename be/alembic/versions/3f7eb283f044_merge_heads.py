"""merge heads

Revision ID: 3f7eb283f044
Revises: a3acb9010600, d1e2f3a4b5c7
Create Date: 2026-08-30 22:02:50.098686

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '3f7eb283f044'
down_revision: Union[str, None] = ('a3acb9010600', 'd1e2f3a4b5c7')
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
