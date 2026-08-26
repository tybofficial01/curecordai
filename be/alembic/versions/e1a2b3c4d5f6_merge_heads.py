"""merge heads

Revision ID: e1a2b3c4d5f6
Revises: d4e8f2a61b95, c7d9e2f1a3b8
Create Date: 2026-07-08 00:00:00.000000

"""
from typing import Sequence, Union


# revision identifiers, used by Alembic.
revision: str = 'e1a2b3c4d5f6'
down_revision: Union[str, Sequence[str], None] = ('d4e8f2a61b95', 'c7d9e2f1a3b8')
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
