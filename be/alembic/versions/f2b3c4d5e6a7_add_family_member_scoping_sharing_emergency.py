"""add family_member_id scoping to sharing and emergency

Revision ID: f2b3c4d5e6a7
Revises: e1a2b3c4d5f6
Create Date: 2026-07-08 00:00:00.000001

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'f2b3c4d5e6a7'
down_revision: Union[str, None] = 'e1a2b3c4d5f6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ── doctor_share_sessions ───────────────────────────────────────────────
    op.add_column('doctor_share_sessions', sa.Column('family_member_id', sa.UUID(), nullable=True))
    op.create_foreign_key(
        'fk_doctor_share_sessions_family_member_id', 'doctor_share_sessions',
        'family_members', ['family_member_id'], ['id'], ondelete='SET NULL',
    )
    op.create_index(
        'idx_doctor_share_family_member_id', 'doctor_share_sessions', ['family_member_id'], unique=False,
    )

    # ── emergency_contacts ──────────────────────────────────────────────────
    op.add_column('emergency_contacts', sa.Column('family_member_id', sa.UUID(), nullable=True))
    op.create_foreign_key(
        'fk_emergency_contacts_family_member_id', 'emergency_contacts',
        'family_members', ['family_member_id'], ['id'], ondelete='SET NULL',
    )
    op.create_index(
        'idx_emergency_contacts_family_member_id', 'emergency_contacts', ['family_member_id'], unique=False,
    )

    # ── emergency_settings - was one row per user; now one row per (user, family_member) ──
    op.add_column('emergency_settings', sa.Column('family_member_id', sa.UUID(), nullable=True))
    op.create_foreign_key(
        'fk_emergency_settings_family_member_id', 'emergency_settings',
        'family_members', ['family_member_id'], ['id'], ondelete='SET NULL',
    )
    op.drop_constraint('emergency_settings_user_id_key', 'emergency_settings', type_='unique')
    op.create_unique_constraint(
        'uq_emergency_settings_user_family_member', 'emergency_settings', ['user_id', 'family_member_id'],
    )


def downgrade() -> None:
    op.drop_constraint('uq_emergency_settings_user_family_member', 'emergency_settings', type_='unique')
    op.create_unique_constraint('emergency_settings_user_id_key', 'emergency_settings', ['user_id'])
    op.drop_constraint('fk_emergency_settings_family_member_id', 'emergency_settings', type_='foreignkey')
    op.drop_column('emergency_settings', 'family_member_id')

    op.drop_index('idx_emergency_contacts_family_member_id', table_name='emergency_contacts')
    op.drop_constraint('fk_emergency_contacts_family_member_id', 'emergency_contacts', type_='foreignkey')
    op.drop_column('emergency_contacts', 'family_member_id')

    op.drop_index('idx_doctor_share_family_member_id', table_name='doctor_share_sessions')
    op.drop_constraint('fk_doctor_share_sessions_family_member_id', 'doctor_share_sessions', type_='foreignkey')
    op.drop_column('doctor_share_sessions', 'family_member_id')
