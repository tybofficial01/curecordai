"""
Structured patient snapshot for AI chat context (Phase 1 - grounding without RAG).
Builds a compact summary from already-extracted clinical tables (Condition, MedicationRequest,
AllergyIntolerance, Observation, Encounter) instead of re-sending raw documents.
"""
import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.scoping import family_scope
from app.models.clinical import AllergyIntolerance, Condition, Encounter, MedicationRequest, Observation
from app.models.medication_reminder import MedicationReminder

_MAX_CONDITIONS = 15
_MAX_MEDICATIONS = 15
_MAX_ALLERGIES = 10
_MAX_OBSERVATIONS = 20
_MAX_ENCOUNTERS = 5
_MAX_SNAPSHOT_CHARS = 3000


async def build_snapshot(
    db: AsyncSession, user_id: uuid.UUID, family_member_id: uuid.UUID | None
) -> tuple[str | None, set[uuid.UUID]]:
    """
    Returns (snapshot_text, source_record_ids). snapshot_text is None when the patient has
    no structured clinical data yet (e.g. no documents processed).
    """
    conditions = (await db.scalars(
        select(Condition).where(
            Condition.user_id == user_id,
            family_scope(Condition, family_member_id),
            Condition.is_deleted == False,  # noqa: E712
            Condition.clinical_status.in_(("active", "recurrence", "relapse")),
        ).order_by(Condition.onset_date.desc().nullslast()).limit(_MAX_CONDITIONS)
    )).all()

    # Only medications the user has an active reminder for are "active" - being
    # mentioned in a document never implies that on its own.
    medications = (await db.scalars(
        select(MedicationRequest)
        .join(MedicationReminder, MedicationReminder.medication_request_id == MedicationRequest.id)
        .where(
            MedicationRequest.user_id == user_id,
            family_scope(MedicationRequest, family_member_id),
            MedicationRequest.is_deleted == False,  # noqa: E712
            MedicationReminder.status == "active",
            MedicationReminder.is_deleted == False,  # noqa: E712
        ).order_by(MedicationRequest.prescribed_date.desc().nullslast()).limit(_MAX_MEDICATIONS)
        .distinct()
    )).all()

    allergies = (await db.scalars(
        select(AllergyIntolerance).where(
            AllergyIntolerance.user_id == user_id,
            family_scope(AllergyIntolerance, family_member_id),
            AllergyIntolerance.is_deleted == False,  # noqa: E712
            AllergyIntolerance.clinical_status == "active",
        ).limit(_MAX_ALLERGIES)
    )).all()

    observations = (await db.scalars(
        select(Observation).where(
            Observation.user_id == user_id,
            family_scope(Observation, family_member_id),
            Observation.is_deleted == False,  # noqa: E712
        ).order_by(Observation.effective_datetime.desc().nullslast()).limit(_MAX_OBSERVATIONS)
    )).all()
    observations = sorted(observations, key=lambda o: o.interpretation in (None, "normal"))

    encounters = (await db.scalars(
        select(Encounter).where(
            Encounter.user_id == user_id,
            family_scope(Encounter, family_member_id),
            Encounter.is_deleted == False,  # noqa: E712
        ).order_by(Encounter.start_datetime.desc().nullslast()).limit(_MAX_ENCOUNTERS)
    )).all()

    record_ids = {
        row.source_record_id
        for row in (*conditions, *medications, *allergies, *observations, *encounters)
        if row.source_record_id
    }

    if not any((conditions, medications, allergies, observations, encounters)):
        return None, record_ids

    lines = []
    if conditions:
        lines.append("Active conditions: " + "; ".join(
            c.condition_name + (f" (since {c.onset_date})" if c.onset_date else "")
            for c in conditions
        ))
    if medications:
        lines.append("Current medications: " + "; ".join(
            f"{m.medication_name_raw} {m.dosage_instruction or ''} {m.dose_frequency or ''}".strip()
            for m in medications
        ))
    if allergies:
        lines.append("Allergies: " + "; ".join(
            a.substance_name + (f" (reaction: {a.reaction_description})" if a.reaction_description else "")
            for a in allergies
        ))
    if observations:
        lines.append("Recent labs/vitals: " + "; ".join(
            f"{o.observation_name} {o.value_quantity if o.value_quantity is not None else (o.value_string or '')} "
            f"{o.value_unit or ''}".strip() + (f" [{o.interpretation}]" if o.interpretation else "")
            for o in observations
        ))
    if encounters:
        lines.append("Recent encounters: " + "; ".join(
            e.title + (f" on {e.start_datetime.date()}" if e.start_datetime else "")
            for e in encounters
        ))

    snapshot = "\n".join(lines)
    if len(snapshot) > _MAX_SNAPSHOT_CHARS:
        snapshot = snapshot[:_MAX_SNAPSHOT_CHARS] + "…"

    return snapshot, record_ids
