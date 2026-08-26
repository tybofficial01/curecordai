"""Enforce audit.audit_logs immutability at the DB level (SECURITY_AUDIT.md M5)

A BEFORE UPDATE/DELETE trigger blocks mutation regardless of which role issues it -
REVOKE alone doesn't cover a role that owns the table. REVOKE is still applied for any
non-owner role that might be granted access to the audit schema later.

Revision ID: b4e0d3f2a1c7
Revises: a3f9c1d2e4b6
Create Date: 2026-08-08 00:00:01.000000

"""
from typing import Sequence, Union

from alembic import op

revision: str = 'b4e0d3f2a1c7'
down_revision: Union[str, None] = 'a3f9c1d2e4b6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute("REVOKE UPDATE, DELETE ON audit.audit_logs FROM PUBLIC")
    op.execute("""
        CREATE OR REPLACE FUNCTION audit.prevent_audit_log_mutation()
        RETURNS TRIGGER AS $$
        BEGIN
            RAISE EXCEPTION 'audit.audit_logs is append-only - % is not permitted', TG_OP;
        END;
        $$ LANGUAGE plpgsql;
    """)
    op.execute("""
        CREATE TRIGGER audit_logs_immutable
        BEFORE UPDATE OR DELETE ON audit.audit_logs
        FOR EACH ROW EXECUTE FUNCTION audit.prevent_audit_log_mutation();
    """)


def downgrade() -> None:
    op.execute("DROP TRIGGER IF EXISTS audit_logs_immutable ON audit.audit_logs")
    op.execute("DROP FUNCTION IF EXISTS audit.prevent_audit_log_mutation()")
