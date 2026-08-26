"""Add medication reminders and dose logs

Revision ID: d8a1f4c2b6e9
Revises: b4e0d3f2a1c7
Create Date: 2026-08-11 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = 'd8a1f4c2b6e9'
down_revision: Union[str, None] = 'b4e0d3f2a1c7'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'medication_reminders',
        sa.Column('id', postgresql.UUID(as_uuid=True), server_default=sa.text('gen_random_uuid()'), nullable=False),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('family_member_id', postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column('source', sa.String(length=20), nullable=False, server_default='manual'),
        sa.Column('medication_request_id', postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column('source_record_id', postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column('medication_name', sa.String(length=255), nullable=False),
        sa.Column('dosage', sa.String(length=100), nullable=True),
        sa.Column('form', sa.String(length=50), nullable=True),
        sa.Column('instructions', sa.Text(), nullable=True),
        sa.Column('frequency_type', sa.String(length=20), nullable=False, server_default='daily'),
        sa.Column('days_of_week', postgresql.JSONB(), nullable=True),
        sa.Column('interval_days', sa.Integer(), nullable=True),
        sa.Column('times_of_day', postgresql.JSONB(), nullable=False),
        sa.Column('timezone', sa.String(length=64), nullable=False, server_default='UTC'),
        sa.Column('start_date', sa.Date(), nullable=False),
        sa.Column('end_date', sa.Date(), nullable=True),
        sa.Column('status', sa.String(length=20), nullable=False, server_default='active'),
        sa.Column('email_reminders_enabled', sa.Boolean(), nullable=False, server_default='true'),
        sa.Column('push_reminders_enabled', sa.Boolean(), nullable=False, server_default='true'),
        sa.Column('created_by_id', postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column('updated_by_id', postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('is_deleted', sa.Boolean(), nullable=False, server_default='false'),
        sa.Column('deleted_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('deleted_by_id', postgresql.UUID(as_uuid=True), nullable=True),
        sa.PrimaryKeyConstraint('id'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['family_member_id'], ['family_members.id'], ondelete='SET NULL'),
        sa.ForeignKeyConstraint(['medication_request_id'], ['medication_requests.id'], ondelete='SET NULL'),
        sa.ForeignKeyConstraint(['source_record_id'], ['medical_records.id'], ondelete='SET NULL'),
    )
    op.create_index('idx_med_reminders_user_id', 'medication_reminders', ['user_id'])
    op.create_index('idx_med_reminders_user_active', 'medication_reminders', ['user_id', 'is_deleted', 'status'])
    op.create_index('idx_med_reminders_family_member_id', 'medication_reminders', ['family_member_id'])
    op.create_index('idx_med_reminders_medication_request_id', 'medication_reminders', ['medication_request_id'])

    op.create_table(
        'medication_dose_logs',
        sa.Column('id', postgresql.UUID(as_uuid=True), server_default=sa.text('gen_random_uuid()'), nullable=False),
        sa.Column('reminder_id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('family_member_id', postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column('scheduled_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('status', sa.String(length=20), nullable=False, server_default='pending'),
        sa.Column('email_sent_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('taken_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.PrimaryKeyConstraint('id'),
        sa.ForeignKeyConstraint(['reminder_id'], ['medication_reminders.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['family_member_id'], ['family_members.id'], ondelete='SET NULL'),
        sa.UniqueConstraint('reminder_id', 'scheduled_at', name='uq_dose_log_reminder_scheduled_at'),
    )
    op.create_index('idx_dose_logs_user_id', 'medication_dose_logs', ['user_id'])
    op.create_index('idx_dose_logs_reminder_id', 'medication_dose_logs', ['reminder_id'])
    op.create_index('idx_dose_logs_status_scheduled', 'medication_dose_logs', ['status', 'scheduled_at'])


def downgrade() -> None:
    op.drop_index('idx_dose_logs_status_scheduled', table_name='medication_dose_logs')
    op.drop_index('idx_dose_logs_reminder_id', table_name='medication_dose_logs')
    op.drop_index('idx_dose_logs_user_id', table_name='medication_dose_logs')
    op.drop_table('medication_dose_logs')

    op.drop_index('idx_med_reminders_medication_request_id', table_name='medication_reminders')
    op.drop_index('idx_med_reminders_family_member_id', table_name='medication_reminders')
    op.drop_index('idx_med_reminders_user_active', table_name='medication_reminders')
    op.drop_index('idx_med_reminders_user_id', table_name='medication_reminders')
    op.drop_table('medication_reminders')
