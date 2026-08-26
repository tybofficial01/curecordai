"""Encrypt PHI/PII columns at rest with AES-256-GCM

Revision ID: d1e2f3a4b5c7
Revises: c3d5e7f9a1b4
Create Date: 2026-08-30 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = 'd1e2f3a4b5c7'
down_revision: Union[str, None] = 'c3d5e7f9a1b4'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

# (table, column) pairs converted from plaintext TEXT/VARCHAR to AES-256-GCM
# ciphertext (BYTEA), written/read via app.core.encryption.EncryptedString.
COLUMNS = [
    ("allergy_intolerances", "substance_name"),
    ("allergy_intolerances", "snomed_display"),
    ("allergy_intolerances", "reaction_description"),
    ("allergy_intolerances", "ai_correction_note"),
    ("conditions", "condition_name"),
    ("conditions", "icd11_display"),
    ("conditions", "snomed_display"),
    ("conditions", "attending_physician"),
    ("conditions", "care_plan_notes"),
    ("conditions", "ai_correction_note"),
    ("medication_requests", "medication_name_raw"),
    ("medication_requests", "dosage_instruction"),
    ("medication_requests", "prescribing_doctor"),
    ("medication_requests", "ai_correction_note"),
    ("observations", "loinc_display"),
    ("observations", "observation_name"),
    ("observations", "value_string"),
    ("observations", "body_site"),
    ("observations", "ai_correction_note"),
    ("observation_components", "loinc_display"),
    ("observation_components", "component_name"),
    ("observation_components", "value_string"),
    ("encounters", "title"),
    ("encounters", "description"),
    ("encounters", "practitioner_name"),
    ("encounters", "practitioner_specialty"),
    ("encounters", "organization_name"),
    ("encounters", "ai_correction_note"),
    ("medical_records", "title"),
    ("medical_records", "patient_name_on_doc"),
    ("medical_records", "laboratory_name"),
    ("medical_records", "referring_doctor"),
    ("medical_records", "issuing_organization"),
    ("medical_records", "extracted_text"),
    ("medical_records", "ai_summary"),
    ("record_chunks", "chunk_text"),
    ("emergency_contacts", "full_name"),
    ("emergency_contacts", "phone_number"),
    ("user_profiles", "full_name"),
    ("family_members", "full_name"),
    ("medication_reminders", "medication_name"),
    ("medication_reminders", "instructions"),
    ("ai_chat_sessions", "title"),
    ("ai_chat_messages", "content"),
    ("ai_chat_messages", "flag_reason"),
    ("ai_chat_history_summaries", "summary_text"),
    ("alerts", "title"),
    ("alerts", "message"),
    ("consent_records", "withdrawal_reason"),
    ("doctor_share_sessions", "scanned_by_name"),
    ("doctor_share_sessions", "scanned_by_institution"),
    ("doctor_instructions", "doctor_name"),
    ("doctor_instructions", "doctor_institution"),
    ("doctor_instructions", "instructions"),
    ("data_sharing_consents", "grantee_name"),
    ("data_sharing_consents", "grantee_institution"),
]

# Every table with a column in COLUMNS. Emptied before the type change: existing
# plaintext values can't be reinterpreted as ciphertext, and several of these
# columns are NOT NULL, so an in-place USING NULL cast would violate the
# constraint. Acceptable pre-production - no important data is at risk.
TABLES = [
    "ai_chat_history_summaries",
    "ai_chat_messages",
    "ai_chat_sessions",
    "alerts",
    "allergy_intolerances",
    "conditions",
    "consent_records",
    "data_sharing_consents",
    "doctor_instructions",
    "doctor_share_sessions",
    "emergency_contacts",
    "encounters",
    "family_members",
    "medical_records",
    "medication_reminders",
    "medication_requests",
    "observation_components",
    "observations",
    "record_chunks",
    "user_profiles",
]


def upgrade() -> None:
    for table in TABLES:
        op.execute(f'TRUNCATE TABLE {table} CASCADE')
    for table, column in COLUMNS:
        op.execute(f'ALTER TABLE {table} ALTER COLUMN {column} DROP DEFAULT')
        op.execute(f'ALTER TABLE {table} ALTER COLUMN {column} TYPE BYTEA USING NULL')


def downgrade() -> None:
    for table, column in COLUMNS:
        op.execute(f'ALTER TABLE {table} ALTER COLUMN {column} TYPE TEXT USING NULL')
