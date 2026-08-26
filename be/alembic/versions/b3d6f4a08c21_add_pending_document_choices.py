"""Add pending_document_choices to ai_chat_sessions

Revision ID: b3d6f4a08c21
Revises: 91015934f8ec
Create Date: 2026-09-04 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = 'b3d6f4a08c21'
down_revision: Union[str, None] = '91015934f8ec'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        'ai_chat_sessions',
        sa.Column('pending_document_choices', sa.Text(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column('ai_chat_sessions', 'pending_document_choices')
