"""Normalize deprecated 'ar' app_settings.language values to 'en'

Revision ID: a3acb9010600
Revises: c3d5e7f9a1b4
Create Date: 2026-08-29T14:29:20

Data-only migration: the app_settings.language column (String(10)) already exists and
already fits the new 'roman_ur' value (8 chars), so no schema change is needed here.
The API layer's allowed language set is being narrowed to exactly {en, ur, roman_ur} -
'ar' (Arabic) was never a documented/spec'd option and is being dropped. Any existing
row already holding 'ar' would otherwise fail the new Pydantic validation on every read,
so this defensively normalizes those rows to the safe default 'en'.
"""
from typing import Sequence, Union

from alembic import op

# revision identifiers, used by Alembic.
revision: str = 'a3acb9010600'
down_revision: Union[str, None] = 'c3d5e7f9a1b4'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Idempotent by construction (WHERE clause only matches rows still set to 'ar').
    op.execute("UPDATE app_settings SET language = 'en' WHERE language = 'ar'")


def downgrade() -> None:
    # No-op: we cannot know which rows were originally 'ar' (that information is
    # overwritten by upgrade()), so there is nothing safe to restore.
    pass
