"""
Insights/Analytics API - all data sourced from our own DB only (no third-party analytics).
GDPR: analytics_opt_in must be True to aggregate personal data beyond basic counts.
"""
import uuid
from datetime import datetime, timedelta, timezone

import structlog
from fastapi import APIRouter, Request
from pydantic import BaseModel
from sqlalchemy import func as sqlfunc
from sqlalchemy import select

from app.core.enums import Language
from app.core.rate_limit import limiter
from app.core.scoping import family_scope
from app.dependencies import CurrentUser, DB
from app.models.alerts import Alert
from app.models.clinical import AllergyIntolerance, Condition, MedicationRequest, Observation
from app.models.medication_reminder import MedicationReminder
from app.models.records import MedicalRecord
from app.models.settings import AppSetting
from app.schemas.clinical import AllergyOut, ConditionOut, MedicationRequestOut, ObservationOut
from app.services.openrouter import summarize_health_overview
from app.services.patient_context import build_snapshot

logger = structlog.get_logger()

router = APIRouter(prefix="/insights", tags=["insights"])


class HealthSummaryOut(BaseModel):
    total_records: int
    active_conditions: int
    active_medications: int
    active_allergies: int
    records_this_month: int
    unread_alerts: int


class ObservationTrendPoint(BaseModel):
    date: datetime
    value: float
    unit: str | None


class ObservationTrendOut(BaseModel):
    loinc_code: str
    observation_name: str
    points: list[ObservationTrendPoint]


class HealthOverviewOut(BaseModel):
    narrative_summary: str | None  # None when the patient has no clinical data yet
    conditions: list[ConditionOut]
    medications: list[MedicationRequestOut]
    allergies: list[AllergyOut]
    recent_observations: list[ObservationOut]


@router.get("/summary", response_model=HealthSummaryOut, summary="Dashboard health summary counts")
async def health_summary(current_user: CurrentUser, db: DB, family_member_id: uuid.UUID | None = None):
    uid = current_user.id
    now = datetime.now(timezone.utc)
    month_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)

    def _count(model, *conditions):
        return select(sqlfunc.count()).select_from(model).where(*conditions).scalar_subquery()

    # total_records and records_this_month both scan medical_records - compute them
    # in one pass with a FILTER clause instead of two separate table scans.
    records_counts = (
        select(
            sqlfunc.count().label("total_records"),
            sqlfunc.count().filter(MedicalRecord.uploaded_at >= month_start).label("records_this_month"),
        )
        .select_from(MedicalRecord)
        .where(
            MedicalRecord.user_id == uid,
            MedicalRecord.is_deleted == False,  # noqa: E712
            family_scope(MedicalRecord, family_member_id),
        )
        .subquery()
    )

    (
        total_records,
        active_conditions,
        active_medications,
        active_allergies,
        records_this_month,
        unread_alerts,
    ) = (await db.execute(
        select(
            records_counts.c.total_records,
            _count(
                Condition,
                Condition.user_id == uid,
                Condition.clinical_status == "active",
                Condition.is_deleted == False,  # noqa: E712
                family_scope(Condition, family_member_id),
            ),
            # "Active medications" means the user has an active medication reminder -
            # medications merely extracted from a document are not active on their own.
            _count(
                MedicationReminder,
                MedicationReminder.user_id == uid,
                MedicationReminder.status == "active",
                MedicationReminder.is_deleted == False,  # noqa: E712
                family_scope(MedicationReminder, family_member_id),
            ),
            _count(
                AllergyIntolerance,
                AllergyIntolerance.user_id == uid,
                AllergyIntolerance.clinical_status == "active",
                AllergyIntolerance.is_deleted == False,  # noqa: E712
                family_scope(AllergyIntolerance, family_member_id),
            ),
            records_counts.c.records_this_month,
            # Alerts are account-level (no family_member_id column on the model) -
            # always the owner's own, regardless of which family member is active.
            _count(
                Alert,
                Alert.user_id == uid,
                Alert.is_read == False,  # noqa: E712
                Alert.is_deleted == False,  # noqa: E712
            ),
        ).select_from(records_counts)
    )).one()

    logger.debug(
        "Health summary computed",
        user_id=str(uid),
        total_records=total_records or 0,
        active_conditions=active_conditions or 0,
        active_medications=active_medications or 0,
        active_allergies=active_allergies or 0,
        unread_alerts=unread_alerts or 0,
    )
    return HealthSummaryOut(
        total_records=total_records or 0,
        active_conditions=active_conditions or 0,
        active_medications=active_medications or 0,
        active_allergies=active_allergies or 0,
        records_this_month=records_this_month or 0,
        unread_alerts=unread_alerts or 0,
    )


@router.get(
    "/trends/{loinc_code}",
    response_model=ObservationTrendOut,
    summary="Lab/vital trend data for a given LOINC code (last 90 days)",
)
async def observation_trend(
    loinc_code: str,
    current_user: CurrentUser,
    db: DB,
    days: int = 90,
    family_member_id: uuid.UUID | None = None,
):
    cutoff = datetime.now(timezone.utc) - timedelta(days=min(days, 365))
    # Trend rows can number in the hundreds - select only the columns the response
    # needs instead of hydrating full Observation entities (~30 columns each).
    rows = (await db.execute(
        select(
            Observation.effective_datetime,
            Observation.value_quantity,
            Observation.value_unit,
            Observation.observation_name,
        ).where(
            Observation.user_id == current_user.id,
            Observation.loinc_code == loinc_code,
            Observation.is_deleted == False,  # noqa: E712
            Observation.effective_datetime >= cutoff,
            Observation.value_quantity.is_not(None),
            family_scope(Observation, family_member_id),
        ).order_by(Observation.effective_datetime.asc())
    )).all()

    points = [
        ObservationTrendPoint(
            date=row.effective_datetime,
            value=float(row.value_quantity),
            unit=row.value_unit,
        )
        for row in rows
    ]

    observation_name = rows[0].observation_name if rows else loinc_code
    logger.debug(
        "Observation trend computed",
        user_id=str(current_user.id),
        loinc_code=loinc_code,
        points=len(points),
        days=days,
    )

    return ObservationTrendOut(
        loinc_code=loinc_code,
        observation_name=observation_name,
        points=points,
    )


@router.get(
    "/health-overview",
    response_model=HealthOverviewOut,
    summary="Comprehensive whole-person health summary - AI narrative + structured clinical data",
)
@limiter.limit("10/minute")
async def health_overview(
    request: Request, current_user: CurrentUser, db: DB, family_member_id: uuid.UUID | None = None
):
    uid = current_user.id

    conditions = (await db.scalars(
        select(Condition).where(
            Condition.user_id == uid,
            Condition.is_deleted == False,  # noqa: E712
            Condition.clinical_status.in_(("active", "recurrence", "relapse")),
            family_scope(Condition, family_member_id),
        ).order_by(Condition.onset_date.desc().nullslast())
    )).all()

    # Only document-extracted medications the user has turned into an active reminder
    # count as "current" - extraction alone never implies the medication is active.
    medications = (await db.scalars(
        select(MedicationRequest)
        .join(MedicationReminder, MedicationReminder.medication_request_id == MedicationRequest.id)
        .where(
            MedicationRequest.user_id == uid,
            MedicationRequest.is_deleted == False,  # noqa: E712
            MedicationReminder.status == "active",
            MedicationReminder.is_deleted == False,  # noqa: E712
            family_scope(MedicationRequest, family_member_id),
        ).order_by(MedicationRequest.prescribed_date.desc().nullslast())
        .distinct()
    )).all()

    allergies = (await db.scalars(
        select(AllergyIntolerance).where(
            AllergyIntolerance.user_id == uid,
            AllergyIntolerance.is_deleted == False,  # noqa: E712
            AllergyIntolerance.clinical_status == "active",
            family_scope(AllergyIntolerance, family_member_id),
        )
    )).all()

    recent_observations = (await db.scalars(
        select(Observation).where(
            Observation.user_id == uid,
            Observation.is_deleted == False,  # noqa: E712
            family_scope(Observation, family_member_id),
        ).order_by(Observation.effective_datetime.desc().nullslast()).limit(20)
    )).all()

    # Reuse the same structured-facts snapshot the AI chat uses for personalization - the
    # narrative should read as one coherent overview, not re-derive its own text format.
    snapshot_text, _ = await build_snapshot(db, uid, family_member_id)
    narrative_summary = None
    if snapshot_text:
        # The health overview is always for the account owner (uid), not necessarily the
        # currently-authenticated user, so look up language via that same uid.
        user_language = await db.scalar(select(AppSetting.language).where(AppSetting.user_id == uid))
        language = Language(user_language) if user_language else Language.EN
        result = await summarize_health_overview(
            snapshot_text, language=language, user_id=uid, family_member_id=family_member_id
        )
        narrative_summary = result["summary"]

    logger.info(
        "Health overview generated",
        user_id=str(uid),
        conditions=len(conditions),
        medications=len(medications),
        allergies=len(allergies),
        observations=len(recent_observations),
        has_narrative=narrative_summary is not None,
    )

    return HealthOverviewOut(
        narrative_summary=narrative_summary,
        conditions=[ConditionOut.model_validate(c) for c in conditions],
        medications=[
            MedicationRequestOut.model_validate(m).model_copy(update={"has_active_reminder": True})
            for m in medications
        ],
        allergies=[AllergyOut.model_validate(a) for a in allergies],
        recent_observations=[ObservationOut.model_validate(o) for o in recent_observations],
    )
