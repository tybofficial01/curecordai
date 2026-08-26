"""merge heads

Revision ID: 91015934f8ec
Revises: 3f7eb283f044, 9924969df5ef
Create Date: 2026-08-30 22:20:08.271430

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '91015934f8ec'
down_revision: Union[str, None] = ('3f7eb283f044', '9924969df5ef')
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
