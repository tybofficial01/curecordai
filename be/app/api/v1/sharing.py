"""
Doctor QR sharing - generates a token, stores only its SHA-256 hash.
The raw token travels only inside the QR code image.
The QR encodes a link to a public, unauthenticated page on the frontend
(`{WEB_APP_BASE_URL}/share/{token}`), which calls the JSON endpoint below to
render a standardized, printable health summary - no app or login needed.
"""
import uuid
from datetime import datetime, timedelta, timezone

import structlog
from fastapi import APIRouter, Request, status
from fastapi.responses import HTMLResponse
from jinja2 import Template
from pydantic import BaseModel, Field
from sqlalchemy import func, select, text

from app.config import settings
from app.core.encryption import decrypt_jsonb_row
from app.core.errors import ApiError, ErrorCode
from app.core.rate_limit import limiter
from app.core.scoping import family_scope, validate_family_member_ownership
from app.core.security import generate_token, hash_token
from app.dependencies import CurrentUser, DB
from app.models.sharing import DoctorInstruction, DoctorShareSession

logger = structlog.get_logger()

router = APIRouter(prefix="/share", tags=["sharing"])

# Matches the scope options presented in the app's share screen exactly.
VALID_SHARE_SCOPES = {"last_1_year", "last_6_months", "full", "emergency_only"}
_SCOPE_WINDOW_DAYS = {"last_1_year": 365, "last_6_months": 183}

MAX_INSTRUCTIONS_LENGTH = 4000
MAX_NAME_LENGTH = 255

# Legacy HTML page - kept as a plain fallback for anyone hitting the raw API URL directly.
# The QR code itself now points at the frontend's /share/{token} page, which consumes the
# JSON endpoint further below. Standardized to black-and-white for print/clinical use.
DOCTOR_VIEW_TEMPLATE = """
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>CurecordAI - Patient Health Summary</title>
  <style>
    body { font-family: Georgia, 'Times New Roman', serif;
           background: #ffffff; color: #000000; max-width: 760px; margin: 0 auto; padding: 2rem; }
    .header { border-bottom: 3px solid #000000; padding-bottom: 1rem; margin-bottom: 1.5rem; }
    .section { border: 1px solid #000000; padding: 1.25rem; margin-bottom: 1rem; }
    h1 { margin: 0 0 0.25rem; font-size: 1.5rem; letter-spacing: 0.02em; }
    h2 { color: #000000; font-size: 1rem; margin: 0 0 0.75rem; text-transform: uppercase;
         letter-spacing: 0.05em; border-bottom: 1px solid #000000; padding-bottom: 0.35rem; }
    .tag { border: 1px solid #000000; padding: 0.2rem 0.7rem; font-size: 0.85rem;
           display: inline-block; margin: 0.2rem; }
    .disclaimer { color: #000000; font-size: 0.8rem; border-top: 1px solid #000000;
                  padding-top: 1rem; margin-top: 2rem; }
    .critical { font-weight: bold; text-decoration: underline; }
    .expired { text-align: center; padding: 4rem; color: #000000; }
    @media print { body { padding: 0; } }
  </style>
</head>
<body>
{% if expired %}
<div class="expired">
  <h2>This QR code has expired or is invalid.</h2>
  <p>Please ask the patient to generate a new QR code from their CurecordAI app.</p>
</div>
{% else %}
<div class="header">
  <h1>{{ patient_name or "Patient" }}</h1>
  <p style="margin:0">Shared via CurecordAI &middot; {{ scope }} access &middot; Expires {{ expires_at }}</p>
</div>

{% if blood_group %}<div class="section"><h2>Blood Group</h2><span class="tag">{{ blood_group }}</span></div>{% endif %}

{% if emergency_contacts %}
<div class="section">
  <h2>Emergency Contacts</h2>
  {% for c in emergency_contacts %}
  <span class="tag">{{ c.full_name }}{% if c.relationship %} ({{ c.relationship }}){% endif %} - {{ c.phone_number }}</span>
  {% endfor %}
</div>
{% endif %}

{% if allergies %}
<div class="section">
  <h2>Allergies</h2>
  {% for a in allergies %}
  <span class="tag{% if a.criticality == 'high' %} critical{% endif %}">{{ a.substance_name }}{% if a.criticality == 'high' %} (HIGH RISK){% endif %}</span>
  {% endfor %}
</div>
{% endif %}

{% if conditions %}
<div class="section">
  <h2>Active Conditions</h2>
  {% for c in conditions %}
  <span class="tag">{{ c.condition_name }}</span>
  {% endfor %}
</div>
{% endif %}

{% if medications %}
<div class="section">
  <h2>Current Medications</h2>
  {% for m in medications %}
  <span class="tag">{{ m.display_name }}{% if m.dosage_instruction %} - {{ m.dosage_instruction }}{% endif %}</span>
  {% endfor %}
</div>
{% endif %}

{% if observations %}
<div class="section">
  <h2>Recent Lab Results / Vitals</h2>
  {% for o in observations %}
  <span class="tag">{{ o.observation_name }}: {{ o.value_quantity if o.value_quantity is not none else o.value_string }} {{ o.value_unit or '' }}</span>
  {% endfor %}
</div>
{% endif %}

{% if encounters %}
<div class="section">
  <h2>Recent Visits</h2>
  {% for e in encounters %}
  <span class="tag">{{ e.title }}{% if e.start_datetime %} - {{ e.start_datetime.strftime('%Y-%m-%d') }}{% endif %}</span>
  {% endfor %}
</div>
{% endif %}

<div class="disclaimer">
  This health summary was shared by the patient for informational purposes only.
  CurecordAI is not responsible for clinical decisions made based on this data.
  Always verify information directly with the patient.
</div>
{% endif %}
</body>
</html>
"""


class CreateShareRequest(BaseModel):
    share_scope: str = "full"  # last_1_year | last_6_months | full | emergency_only
    family_member_id: uuid.UUID | None = None


class ShareSessionOut(BaseModel):
    id: uuid.UUID
    share_scope: str
    status: str
    expires_at: datetime
    expires_in_seconds: int = 0  # injected server-side - not stored
    qr_url: str = ""  # the URL to encode in the QR code (contains raw token) - injected server-side
    created_at: datetime

    class Config:
        from_attributes = True


class DoctorInstructionCreate(BaseModel):
    doctor_name: str = Field(..., min_length=1, max_length=MAX_NAME_LENGTH)
    doctor_institution: str = Field(..., min_length=1, max_length=MAX_NAME_LENGTH)
    instructions: str = Field(..., min_length=1, max_length=MAX_INSTRUCTIONS_LENGTH)


@router.post("/qr", response_model=ShareSessionOut, status_code=status.HTTP_201_CREATED)
@limiter.limit("10/hour")
async def create_share_session(request: Request, body: CreateShareRequest, current_user: CurrentUser, db: DB):
    """Generate a new QR share session. Raw token is only returned here - store only the hash."""
    if body.share_scope not in VALID_SHARE_SCOPES:
        raise ApiError(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid share_scope", error_code=ErrorCode.INVALID_SHARE_SCOPE)
    await validate_family_member_ownership(db, current_user.id, body.family_member_id)

    raw_token = generate_token(48)
    token_hash = hash_token(raw_token)
    expires_at = datetime.now(timezone.utc) + timedelta(minutes=settings.QR_SESSION_EXPIRE_MINUTES)

    session = DoctorShareSession(
        user_id=current_user.id,
        family_member_id=body.family_member_id,
        qr_token_hash=token_hash,
        share_scope=body.share_scope,
        status="active",
        expires_at=expires_at,
    )
    db.add(session)
    await db.commit()
    await db.refresh(session)
    logger.info(
        "QR share session created",
        session_id=str(session.id),
        user_id=str(current_user.id),
        scope=body.share_scope,
        expires_at=expires_at.isoformat(),
    )

    # Raw token only in the URL - never stored. Points at the public frontend page, not the API.
    qr_url = f"{settings.WEB_APP_BASE_URL}/share/{raw_token}"

    result = ShareSessionOut.model_validate(session)
    result.qr_url = qr_url
    result.expires_in_seconds = settings.QR_SESSION_EXPIRE_MINUTES * 60
    return result


@router.get("/sessions", summary="List active share sessions for the current user")
async def list_share_sessions(
    current_user: CurrentUser, db: DB, family_member_id: uuid.UUID | None = None
):
    now = datetime.now(timezone.utc)
    sessions = (await db.scalars(
        select(DoctorShareSession)
        .where(
            DoctorShareSession.user_id == current_user.id,
            DoctorShareSession.expires_at > now,
            family_scope(DoctorShareSession, family_member_id),
        )
        .order_by(DoctorShareSession.created_at.desc())
    )).all()
    return [{"id": str(s.id), "scope": s.share_scope, "status": s.status, "expires_at": s.expires_at.isoformat()} for s in sessions]


@router.delete("/sessions/{session_id}", status_code=status.HTTP_204_NO_CONTENT)
async def revoke_share_session(session_id: uuid.UUID, current_user: CurrentUser, db: DB):
    session = await db.scalar(
        select(DoctorShareSession).where(
            DoctorShareSession.id == session_id,
            DoctorShareSession.user_id == current_user.id,
        )
    )
    if not session:
        logger.debug("Share session not found for revoke", session_id=str(session_id), user_id=str(current_user.id))
        raise ApiError(status_code=status.HTTP_404_NOT_FOUND, detail="Share session not found", error_code=ErrorCode.SHARE_SESSION_NOT_FOUND)

    session.status = "revoked"
    session.revoked_at = datetime.now(timezone.utc)
    session.revoke_reason = "user_revoked"
    await db.commit()
    logger.info("QR share session revoked", session_id=str(session_id), user_id=str(current_user.id))


async def _find_active_session(db: DB, token: str) -> DoctorShareSession | None:
    token_hash = hash_token(token)
    now = datetime.now(timezone.utc)
    return await db.scalar(
        select(DoctorShareSession).where(
            DoctorShareSession.qr_token_hash == token_hash,
            DoctorShareSession.status == "active",
            DoctorShareSession.expires_at > now,
        )
    )


async def _record_scan(db: DB, share_session: DoctorShareSession, request: Request) -> None:
    share_session.scanned_at = datetime.now(timezone.utc)
    share_session.scanned_ip = request.client.host if request.client else None
    share_session.scanned_user_agent = request.headers.get("user-agent")
    await db.commit()
    logger.info(
        "Doctor view - share link opened",
        session_id=str(share_session.id),
        user_id=str(share_session.user_id),
        scope=share_session.share_scope,
        scanned_ip=share_session.scanned_ip,
    )


async def _load_share_payload(db: DB, share_session: DoctorShareSession) -> dict:
    """Fetches and shapes the clinical data a given active share session grants access to.
    Shared by the legacy HTML view and the public JSON endpoint so the query logic lives once.
    """
    from app.models.clinical import AllergyIntolerance, Condition, Encounter, Medication, MedicationRequest, Observation
    from app.models.emergency import EmergencyContact
    from app.models.family import FamilyMember
    from app.models.medication_reminder import MedicationReminder
    from app.models.profile import UserProfile

    now = datetime.now(timezone.utc)
    user_id = share_session.user_id
    family_member_id = share_session.family_member_id
    scope = share_session.share_scope

    # Resolve the right identity - the account owner's own profile, or the specific family member
    if family_member_id:
        person = await db.scalar(select(FamilyMember).where(FamilyMember.id == family_member_id))
        patient_name = person.full_name if person else None
        blood_group = person.blood_group if person else None
    else:
        profile = await db.scalar(select(UserProfile).where(UserProfile.user_id == user_id))
        patient_name = profile.full_name if profile else None
        blood_group = profile.blood_group if profile else None

    window_days = _SCOPE_WINDOW_DAYS.get(scope)
    cutoff = now - timedelta(days=window_days) if window_days else None

    emergency_contacts = (await db.scalars(
        select(EmergencyContact).where(
            EmergencyContact.user_id == user_id,
            EmergencyContact.is_deleted == False,  # noqa: E712
            family_scope(EmergencyContact, family_member_id),
        ).order_by(EmergencyContact.is_primary.desc(), EmergencyContact.sort_order.asc())
    )).all()
    emergency_contacts_out = [
        {"full_name": c.full_name, "relationship": c.relationship, "phone_number": c.phone_number}
        for c in emergency_contacts
    ]

    conditions: list = []
    medications: list = []
    observations_out: list = []
    encounters_out: list = []

    def _agg(model, *conditions_):
        # Aggregates a filtered table into one JSON array server-side - lets allergies and
        # conditions (below) be fetched in a single round trip instead of two, safely (no
        # ordering/limit on either, so there's no row-order subtlety to get wrong).
        row = model.__table__.table_valued()
        return (
            select(func.coalesce(func.jsonb_agg(func.to_jsonb(row)), text("'[]'::jsonb")))
            .select_from(model)
            .where(*conditions_)
            .scalar_subquery()
        )

    if scope == "emergency_only":
        allergy_rows = (await db.scalars(
            select(AllergyIntolerance).where(
                AllergyIntolerance.user_id == user_id,
                AllergyIntolerance.clinical_status == "active",
                AllergyIntolerance.is_deleted == False,  # noqa: E712
                family_scope(AllergyIntolerance, family_member_id),
            )
        )).all()
        allergies = [{"substance_name": a.substance_name, "criticality": a.criticality} for a in allergy_rows]
    else:
        cond_filters = [
            Condition.user_id == user_id,
            Condition.clinical_status == "active",
            Condition.is_deleted == False,  # noqa: E712
            family_scope(Condition, family_member_id),
        ]
        if cutoff:
            cond_filters.append(Condition.onset_date >= cutoff.date())

        allergies, conditions = (await db.execute(
            select(
                _agg(
                    AllergyIntolerance,
                    AllergyIntolerance.user_id == user_id,
                    AllergyIntolerance.clinical_status == "active",
                    AllergyIntolerance.is_deleted == False,  # noqa: E712
                    family_scope(AllergyIntolerance, family_member_id),
                ),
                _agg(Condition, *cond_filters),
            )
        )).one()
        allergies = [decrypt_jsonb_row(a, AllergyIntolerance) for a in allergies]
        conditions = [decrypt_jsonb_row(c, Condition) for c in conditions]

        # Only medications the user has an active reminder for count as "active" -
        # being mentioned in a document never implies that on its own.
        med_query = (
            select(MedicationRequest)
            .join(MedicationReminder, MedicationReminder.medication_request_id == MedicationRequest.id)
            .where(
                MedicationRequest.user_id == user_id,
                MedicationRequest.is_deleted == False,  # noqa: E712
                MedicationReminder.status == "active",
                MedicationReminder.is_deleted == False,  # noqa: E712
                family_scope(MedicationRequest, family_member_id),
            )
            .distinct()
        )
        if cutoff:
            med_query = med_query.where(MedicationRequest.prescribed_date >= cutoff.date())
        med_rows = (await db.scalars(med_query)).all()
        # Standardized/generic name preferred over raw AI-extracted text. Batch-fetch the
        # catalog rows instead of one query per medication (N+1).
        medication_ids = {m.medication_id for m in med_rows if m.medication_id}
        catalog_by_id = {}
        if medication_ids:
            catalog_rows = (await db.scalars(
                select(Medication).where(Medication.id.in_(medication_ids))
            )).all()
            catalog_by_id = {c.id: c for c in catalog_rows}

        medications = []
        for m in med_rows:
            display_name = m.medication_name_raw
            catalog = catalog_by_id.get(m.medication_id)
            if catalog and (catalog.generic_name or catalog.atc_display):
                display_name = catalog.generic_name or catalog.atc_display
            medications.append({"display_name": display_name, "dosage_instruction": m.dosage_instruction})

        obs_query = select(Observation).where(
            Observation.user_id == user_id,
            Observation.is_deleted == False,  # noqa: E712
            family_scope(Observation, family_member_id),
        )
        if cutoff:
            obs_query = obs_query.where(Observation.effective_datetime >= cutoff)
        observations = (await db.scalars(
            obs_query.order_by(Observation.effective_datetime.desc().nullslast()).limit(20)
        )).all()
        observations_out = [
            {
                "observation_name": o.observation_name,
                "value_quantity": o.value_quantity,
                "value_string": o.value_string,
                "value_unit": o.value_unit,
                "effective_datetime": o.effective_datetime.isoformat() if o.effective_datetime else None,
            }
            for o in observations
        ]

        enc_query = select(Encounter).where(
            Encounter.user_id == user_id,
            Encounter.is_deleted == False,  # noqa: E712
            family_scope(Encounter, family_member_id),
        )
        if cutoff:
            enc_query = enc_query.where(Encounter.start_datetime >= cutoff)
        encounters = (await db.scalars(
            enc_query.order_by(Encounter.start_datetime.desc().nullslast()).limit(10)
        )).all()
        encounters_out = [
            {"title": e.title, "start_datetime": e.start_datetime.isoformat() if e.start_datetime else None}
            for e in encounters
        ]

    return {
        "patient_name": patient_name,
        "blood_group": blood_group,
        "scope": scope,
        "expires_at": share_session.expires_at,
        "allergies": allergies,
        "conditions": conditions,
        "medications": medications,
        "observations": observations_out,
        "encounters": encounters_out,
        "emergency_contacts": emergency_contacts_out,
    }


@router.get(
    "/view/{token}/data",
    include_in_schema=False,  # Public endpoint - not in API docs
    summary="Doctor JSON view - no auth required - consumed by the frontend /share/{token} page",
)
@limiter.limit("20/minute")
async def doctor_view_data(token: str, request: Request, db: DB):
    """Public JSON payload for the frontend's standardized, black-and-white share page."""
    share_session = await _find_active_session(db, token)
    if not share_session:
        logger.info("Doctor view accessed with expired/invalid token", client_ip=request.client.host if request.client else None)
        return {"expired": True}

    await _record_scan(db, share_session, request)
    payload = await _load_share_payload(db, share_session)
    payload["expired"] = False
    payload["expires_at"] = payload["expires_at"].isoformat()
    return payload


@router.post(
    "/view/{token}/instructions",
    status_code=status.HTTP_201_CREATED,
    include_in_schema=False,  # Public endpoint - not in API docs
    summary="Doctor submits follow-up instructions - no auth required",
)
@limiter.limit("5/hour")
async def submit_doctor_instructions(token: str, body: DoctorInstructionCreate, request: Request, db: DB):
    """A doctor viewing a shared record leaves instructions the patient will see in their app."""
    share_session = await _find_active_session(db, token)
    if not share_session:
        raise ApiError(status_code=status.HTTP_404_NOT_FOUND, detail="This share link has expired or is invalid", error_code=ErrorCode.SHARE_LINK_INVALID)

    doctor_name = body.doctor_name.strip()
    doctor_institution = body.doctor_institution.strip()
    instructions_text = body.instructions.strip()
    if not doctor_name or not doctor_institution or not instructions_text:
        raise ApiError(status_code=status.HTTP_400_BAD_REQUEST, detail="Doctor name, institution, and instructions are required", error_code=ErrorCode.DOCTOR_INSTRUCTIONS_REQUIRED)

    if not share_session.scanned_by_name:
        share_session.scanned_by_name = doctor_name
        share_session.scanned_by_institution = doctor_institution

    instruction = DoctorInstruction(
        share_session_id=share_session.id,
        doctor_name=doctor_name,
        doctor_institution=doctor_institution,
        instructions=instructions_text,
    )
    db.add(instruction)
    await db.commit()
    logger.info(
        "Doctor instructions submitted",
        session_id=str(share_session.id),
        user_id=str(share_session.user_id),
    )
    return {"status": "submitted"}


@router.get("/instructions", summary="List doctor instructions left on the current user's share sessions")
async def list_doctor_instructions(
    current_user: CurrentUser, db: DB, family_member_id: uuid.UUID | None = None
):
    rows = (await db.execute(
        select(DoctorInstruction, DoctorShareSession.share_scope)
        .join(DoctorShareSession, DoctorInstruction.share_session_id == DoctorShareSession.id)
        .where(
            DoctorShareSession.user_id == current_user.id,
            family_scope(DoctorShareSession, family_member_id),
        )
        .order_by(DoctorInstruction.created_at.desc())
    )).all()
    return [
        {
            "id": str(instruction.id),
            "doctor_name": instruction.doctor_name,
            "doctor_institution": instruction.doctor_institution,
            "instructions": instruction.instructions,
            "share_scope": scope,
            "seen_at": instruction.seen_at.isoformat() if instruction.seen_at else None,
            "created_at": instruction.created_at.isoformat(),
        }
        for instruction, scope in rows
    ]


@router.patch("/instructions/{instruction_id}/read", status_code=status.HTTP_204_NO_CONTENT)
async def mark_doctor_instruction_read(instruction_id: uuid.UUID, current_user: CurrentUser, db: DB):
    instruction = await db.scalar(
        select(DoctorInstruction)
        .join(DoctorShareSession, DoctorInstruction.share_session_id == DoctorShareSession.id)
        .where(
            DoctorInstruction.id == instruction_id,
            DoctorShareSession.user_id == current_user.id,
        )
    )
    if not instruction:
        raise ApiError(status_code=status.HTTP_404_NOT_FOUND, detail="Instruction not found", error_code=ErrorCode.INSTRUCTION_NOT_FOUND)

    if instruction.seen_at is None:
        instruction.seen_at = datetime.now(timezone.utc)
        await db.commit()


@router.get(
    "/view/{token}",
    response_class=HTMLResponse,
    include_in_schema=False,  # Public endpoint - not in API docs
    summary="Legacy doctor HTML view - no auth required",
)
@limiter.limit("20/minute")
async def doctor_view(token: str, request: Request, db: DB):
    """
    Plain HTML fallback for anyone hitting the raw API URL directly.
    Token is verified by matching its SHA-256 hash. The QR code itself now points at the
    frontend's /share/{token} page instead of this endpoint.
    """
    share_session = await _find_active_session(db, token)
    template = Template(DOCTOR_VIEW_TEMPLATE)

    if not share_session:
        logger.info("Doctor view accessed with expired/invalid token", client_ip=request.client.host if request.client else None)
        return HTMLResponse(template.render(expired=True))

    await _record_scan(db, share_session, request)
    payload = await _load_share_payload(db, share_session)
    payload["expires_at"] = payload["expires_at"].strftime("%Y-%m-%d %H:%M UTC")
    html = template.render(expired=False, **payload)
    return HTMLResponse(html)
