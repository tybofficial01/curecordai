"""
Clinical data APIs: conditions, medications, observations, encounters, allergies.
All endpoints are FHIR R4 aligned and HIPAA-audited.
"""
import uuid
from datetime import datetime, timezone

import structlog
from fastapi import APIRouter, Query, status
from sqlalchemy import select

from app.core.errors import ApiError, ErrorCode
from app.core.scoping import family_scope, validate_family_member_ownership
from app.dependencies import CurrentUser, DB
from app.models.clinical import (
    AllergyIntolerance,
    Condition,
    Encounter,
    MedicationRequest,
    Observation,
)
from app.schemas.clinical import (
    AllergyCreateRequest,
    AllergyOut,
    AllergyUpdateRequest,
    ConditionCreateRequest,
    ConditionOut,
    ConditionUpdateRequest,
    EncounterCreateRequest,
    EncounterOut,
    EncounterUpdateRequest,
    MedicationRequestCreateRequest,
    MedicationRequestOut,
    MedicationRequestUpdateRequest,
    ObservationCreateRequest,
    ObservationOut,
    ObservationUpdateRequest,
)

logger = structlog.get_logger()

router = APIRouter(tags=["clinical"])


def _soft_delete(obj, user_id: uuid.UUID) -> None:
    obj.is_deleted = True
    obj.deleted_at = datetime.now(timezone.utc)
    obj.deleted_by_id = user_id
    logger.info("Clinical entity soft-deleted", entity_type=type(obj).__name__, entity_id=str(obj.id), user_id=str(user_id))


# ── Allergies ─────────────────────────────────────────────────────────────────

@router.get("/allergies/{allergy_id}", response_model=AllergyOut)
async def get_allergy(allergy_id: uuid.UUID, current_user: CurrentUser, db: DB):
    return AllergyOut.model_validate(await _get_or_404(db, AllergyIntolerance, allergy_id, current_user.id))


@router.get("/allergies", response_model=list[AllergyOut])
async def list_allergies(
    current_user: CurrentUser, db: DB,
    family_member_id: uuid.UUID | None = None,
    clinical_status: str | None = None,
):
    q = select(AllergyIntolerance).where(
        AllergyIntolerance.user_id == current_user.id,
        AllergyIntolerance.is_deleted == False,  # noqa: E712
        family_scope(AllergyIntolerance, family_member_id),
    )
    if clinical_status:
        q = q.where(AllergyIntolerance.clinical_status == clinical_status)
    items = (await db.scalars(q.order_by(AllergyIntolerance.created_at.desc()))).all()
    return [AllergyOut.model_validate(i) for i in items]


@router.post("/allergies", response_model=AllergyOut, status_code=status.HTTP_201_CREATED)
async def create_allergy(body: AllergyCreateRequest, current_user: CurrentUser, db: DB):
    await validate_family_member_ownership(db, current_user.id, body.family_member_id)
    obj = AllergyIntolerance(
        user_id=current_user.id,
        family_member_id=body.family_member_id,
        substance_name=body.substance_name,
        category=body.category,
        criticality=body.criticality,
        clinical_status=body.clinical_status,
        verification_status=body.verification_status,
        snomed_code=body.snomed_code,
        snomed_display=body.snomed_display,
        reaction_description=body.reaction_description,
        onset_date=body.onset_date,
        source="patient_reported",
    )
    db.add(obj)
    await db.commit()
    await db.refresh(obj)
    logger.info("Allergy created", allergy_id=str(obj.id), user_id=str(current_user.id))
    return AllergyOut.model_validate(obj)


@router.patch("/allergies/{allergy_id}", response_model=AllergyOut)
async def update_allergy(
    allergy_id: uuid.UUID, body: AllergyUpdateRequest, current_user: CurrentUser, db: DB
):
    obj = await _get_or_404(db, AllergyIntolerance, allergy_id, current_user.id)
    for k, v in body.model_dump(exclude_unset=True).items():
        setattr(obj, k, v)
    if obj.ai_extracted:
        obj.ai_correction_flag = True
    await db.commit()
    await db.refresh(obj)
    return AllergyOut.model_validate(obj)


@router.delete("/allergies/{allergy_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_allergy(allergy_id: uuid.UUID, current_user: CurrentUser, db: DB):
    obj = await _get_or_404(db, AllergyIntolerance, allergy_id, current_user.id)
    _soft_delete(obj, current_user.id)
    await db.commit()


# ── Conditions ────────────────────────────────────────────────────────────────

@router.get("/conditions/{condition_id}", response_model=ConditionOut)
async def get_condition(condition_id: uuid.UUID, current_user: CurrentUser, db: DB):
    return ConditionOut.model_validate(await _get_or_404(db, Condition, condition_id, current_user.id))


@router.get("/conditions", response_model=list[ConditionOut])
async def list_conditions(
    current_user: CurrentUser, db: DB,
    family_member_id: uuid.UUID | None = None,
    clinical_status: str | None = None,
):
    q = select(Condition).where(
        Condition.user_id == current_user.id,
        Condition.is_deleted == False,  # noqa: E712
        family_scope(Condition, family_member_id),
    )
    if clinical_status:
        q = q.where(Condition.clinical_status == clinical_status)
    items = (await db.scalars(q.order_by(Condition.created_at.desc()))).all()
    return [ConditionOut.model_validate(i) for i in items]


@router.post("/conditions", response_model=ConditionOut, status_code=status.HTTP_201_CREATED)
async def create_condition(body: ConditionCreateRequest, current_user: CurrentUser, db: DB):
    await validate_family_member_ownership(db, current_user.id, body.family_member_id)
    obj = Condition(
        user_id=current_user.id,
        family_member_id=body.family_member_id,
        condition_name=body.condition_name,
        clinical_status=body.clinical_status,
        verification_status=body.verification_status,
        severity=body.severity,
        icd11_code=body.icd11_code,
        icd11_display=body.icd11_display,
        snomed_code=body.snomed_code,
        onset_date=body.onset_date,
        abatement_date=body.abatement_date,
        attending_physician=body.attending_physician,
        care_plan_notes=body.care_plan_notes,
        source="patient_reported",
    )
    db.add(obj)
    await db.commit()
    await db.refresh(obj)
    logger.info("Condition created", condition_id=str(obj.id), user_id=str(current_user.id))
    return ConditionOut.model_validate(obj)


@router.patch("/conditions/{condition_id}", response_model=ConditionOut)
async def update_condition(
    condition_id: uuid.UUID, body: ConditionUpdateRequest, current_user: CurrentUser, db: DB
):
    obj = await _get_or_404(db, Condition, condition_id, current_user.id)
    for k, v in body.model_dump(exclude_unset=True).items():
        setattr(obj, k, v)
    if obj.ai_extracted:
        obj.ai_correction_flag = True
    await db.commit()
    await db.refresh(obj)
    return ConditionOut.model_validate(obj)


@router.delete("/conditions/{condition_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_condition(condition_id: uuid.UUID, current_user: CurrentUser, db: DB):
    obj = await _get_or_404(db, Condition, condition_id, current_user.id)
    _soft_delete(obj, current_user.id)
    await db.commit()


# ── Medications ───────────────────────────────────────────────────────────────
# Routed under /medication-requests (not /medications) - that path belongs to the medication
# reminder CRUD API in app/api/v1/medications.py. These two resources are different (this one is
# the raw extraction from a document; a reminder is a user-configured schedule that may reference
# one via medication_request_id) and must not share a path, or one shadows the other.

@router.get("/medication-requests/{medication_id}", response_model=MedicationRequestOut)
async def get_medication(medication_id: uuid.UUID, current_user: CurrentUser, db: DB):
    return MedicationRequestOut.model_validate(await _get_or_404(db, MedicationRequest, medication_id, current_user.id))


@router.get("/medication-requests", response_model=list[MedicationRequestOut])
async def list_medications(
    current_user: CurrentUser, db: DB,
    family_member_id: uuid.UUID | None = None,
    medication_status: str | None = None,
):
    q = select(MedicationRequest).where(
        MedicationRequest.user_id == current_user.id,
        MedicationRequest.is_deleted == False,  # noqa: E712
        family_scope(MedicationRequest, family_member_id),
    )
    if medication_status:
        q = q.where(MedicationRequest.status == medication_status)
    items = (await db.scalars(q.order_by(MedicationRequest.prescribed_date.desc().nulls_last()))).all()
    return [MedicationRequestOut.model_validate(i) for i in items]


@router.post("/medication-requests", response_model=MedicationRequestOut, status_code=status.HTTP_201_CREATED)
async def create_medication(body: MedicationRequestCreateRequest, current_user: CurrentUser, db: DB):
    await validate_family_member_ownership(db, current_user.id, body.family_member_id)
    obj = MedicationRequest(
        user_id=current_user.id,
        family_member_id=body.family_member_id,
        medication_name_raw=body.medication_name_raw,
        dosage_instruction=body.dosage_instruction,
        dose_quantity=body.dose_quantity,
        dose_frequency=body.dose_frequency,
        route=body.route,
        status=body.status,
        intent=body.intent,
        prescribing_doctor=body.prescribing_doctor,
        prescribed_date=body.prescribed_date,
        start_date=body.start_date,
        end_date=body.end_date,
        duration_days=body.duration_days,
    )
    db.add(obj)
    await db.commit()
    await db.refresh(obj)
    logger.info("Medication request created", medication_id=str(obj.id), user_id=str(current_user.id))
    return MedicationRequestOut.model_validate(obj)


@router.patch("/medication-requests/{medication_id}", response_model=MedicationRequestOut)
async def update_medication(
    medication_id: uuid.UUID, body: MedicationRequestUpdateRequest, current_user: CurrentUser, db: DB
):
    obj = await _get_or_404(db, MedicationRequest, medication_id, current_user.id)
    for k, v in body.model_dump(exclude_unset=True).items():
        setattr(obj, k, v)
    if obj.ai_extracted:
        obj.ai_correction_flag = True
    await db.commit()
    await db.refresh(obj)
    return MedicationRequestOut.model_validate(obj)


@router.delete("/medication-requests/{medication_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_medication(medication_id: uuid.UUID, current_user: CurrentUser, db: DB):
    obj = await _get_or_404(db, MedicationRequest, medication_id, current_user.id)
    _soft_delete(obj, current_user.id)
    await db.commit()


# ── Observations ──────────────────────────────────────────────────────────────

@router.get("/observations/{observation_id}", response_model=ObservationOut)
async def get_observation(observation_id: uuid.UUID, current_user: CurrentUser, db: DB):
    return ObservationOut.model_validate(await _get_or_404(db, Observation, observation_id, current_user.id))


@router.get("/observations", response_model=list[ObservationOut])
async def list_observations(
    current_user: CurrentUser, db: DB,
    category: str | None = None,
    loinc_code: str | None = None,
    family_member_id: uuid.UUID | None = None,
    limit: int = Query(100, le=200),
):
    q = select(Observation).where(
        Observation.user_id == current_user.id,
        Observation.is_deleted == False,  # noqa: E712
        family_scope(Observation, family_member_id),
    )
    if category:
        q = q.where(Observation.observation_category == category)
    if loinc_code:
        q = q.where(Observation.loinc_code == loinc_code)
    items = (await db.scalars(q.order_by(Observation.effective_datetime.desc().nulls_last()).limit(limit))).all()
    return [ObservationOut.model_validate(i) for i in items]


@router.post("/observations", response_model=ObservationOut, status_code=status.HTTP_201_CREATED)
async def create_observation(body: ObservationCreateRequest, current_user: CurrentUser, db: DB):
    await validate_family_member_ownership(db, current_user.id, body.family_member_id)
    obj = Observation(
        user_id=current_user.id,
        family_member_id=body.family_member_id,
        observation_name=body.observation_name,
        observation_category=body.observation_category,
        loinc_code=body.loinc_code,
        loinc_display=body.loinc_display,
        status=body.status,
        value_quantity=body.value_quantity,
        value_unit=body.value_unit,
        value_string=body.value_string,
        reference_range_low=body.reference_range_low,
        reference_range_high=body.reference_range_high,
        interpretation=body.interpretation,
        effective_datetime=body.effective_datetime,
        body_site=body.body_site,
    )
    db.add(obj)
    await db.commit()
    await db.refresh(obj)
    logger.info("Observation created", observation_id=str(obj.id), user_id=str(current_user.id))
    return ObservationOut.model_validate(obj)


@router.patch("/observations/{observation_id}", response_model=ObservationOut)
async def update_observation(
    observation_id: uuid.UUID, body: ObservationUpdateRequest, current_user: CurrentUser, db: DB
):
    obj = await _get_or_404(db, Observation, observation_id, current_user.id)
    for k, v in body.model_dump(exclude_unset=True).items():
        setattr(obj, k, v)
    if obj.ai_extracted:
        obj.ai_correction_flag = True
    await db.commit()
    await db.refresh(obj)
    return ObservationOut.model_validate(obj)


@router.delete("/observations/{observation_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_observation(observation_id: uuid.UUID, current_user: CurrentUser, db: DB):
    obj = await _get_or_404(db, Observation, observation_id, current_user.id)
    _soft_delete(obj, current_user.id)
    await db.commit()


# ── Encounters ────────────────────────────────────────────────────────────────

@router.get("/encounters/{encounter_id}", response_model=EncounterOut)
async def get_encounter(encounter_id: uuid.UUID, current_user: CurrentUser, db: DB):
    return EncounterOut.model_validate(await _get_or_404(db, Encounter, encounter_id, current_user.id))


@router.get("/encounters", response_model=list[EncounterOut])
async def list_encounters(
    current_user: CurrentUser, db: DB,
    encounter_type: str | None = None,
    family_member_id: uuid.UUID | None = None,
    limit: int = Query(50, le=200),
):
    q = select(Encounter).where(
        Encounter.user_id == current_user.id,
        Encounter.is_deleted == False,  # noqa: E712
        family_scope(Encounter, family_member_id),
    )
    if encounter_type:
        q = q.where(Encounter.encounter_type == encounter_type)
    items = (await db.scalars(q.order_by(Encounter.start_datetime.desc().nulls_last()).limit(limit))).all()
    return [EncounterOut.model_validate(i) for i in items]


@router.post("/encounters", response_model=EncounterOut, status_code=status.HTTP_201_CREATED)
async def create_encounter(body: EncounterCreateRequest, current_user: CurrentUser, db: DB):
    await validate_family_member_ownership(db, current_user.id, body.family_member_id)
    obj = Encounter(
        user_id=current_user.id,
        family_member_id=body.family_member_id,
        encounter_type=body.encounter_type,
        status=body.status,
        title=body.title,
        description=body.description,
        practitioner_name=body.practitioner_name,
        practitioner_specialty=body.practitioner_specialty,
        organization_name=body.organization_name,
        start_datetime=body.start_datetime,
        end_datetime=body.end_datetime,
        batch_number=body.batch_number,
    )
    db.add(obj)
    await db.commit()
    await db.refresh(obj)
    logger.info("Encounter created", encounter_id=str(obj.id), user_id=str(current_user.id))
    return EncounterOut.model_validate(obj)


@router.patch("/encounters/{encounter_id}", response_model=EncounterOut)
async def update_encounter(
    encounter_id: uuid.UUID, body: EncounterUpdateRequest, current_user: CurrentUser, db: DB
):
    obj = await _get_or_404(db, Encounter, encounter_id, current_user.id)
    for k, v in body.model_dump(exclude_unset=True).items():
        setattr(obj, k, v)
    if obj.ai_extracted:
        obj.ai_correction_flag = True
    await db.commit()
    await db.refresh(obj)
    return EncounterOut.model_validate(obj)


@router.delete("/encounters/{encounter_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_encounter(encounter_id: uuid.UUID, current_user: CurrentUser, db: DB):
    obj = await _get_or_404(db, Encounter, encounter_id, current_user.id)
    _soft_delete(obj, current_user.id)
    await db.commit()


# ── Helper ────────────────────────────────────────────────────────────────────

async def _get_or_404(db, model_class, obj_id: uuid.UUID, user_id: uuid.UUID):
    obj = await db.scalar(
        select(model_class).where(
            model_class.id == obj_id,
            model_class.user_id == user_id,
            model_class.is_deleted == False,  # noqa: E712
        )
    )
    if not obj:
        logger.debug("Clinical entity not found", entity_type=model_class.__name__, entity_id=str(obj_id), user_id=str(user_id))
        raise ApiError(status_code=status.HTTP_404_NOT_FOUND, detail="Not found", error_code=ErrorCode.CLINICAL_ENTITY_NOT_FOUND)
    return obj
