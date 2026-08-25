"""
Consent management API.
PDPA (Pakistan) + GDPR (EU) - consent must be recorded before data collection,
and users must be able to review and withdraw consent at any time.
"""
import uuid
from datetime import datetime, timezone

import structlog
from fastapi import APIRouter, Request, status
from pydantic import BaseModel
from sqlalchemy import select

from app.core.errors import ApiError, ErrorCode
from app.dependencies import CurrentUser, DB
from app.models.consent import ConsentRecord, DataDeletionRequest, DataExportRequest

logger = structlog.get_logger()

router = APIRouter(prefix="/consent", tags=["consent"])

CURRENT_POLICY_VERSION = "1.0"


class ConsentGrantRequest(BaseModel):
    consent_type: str  # "terms_of_service" | "privacy_policy" | "data_processing" | "analytics"
    is_granted: bool
    jurisdiction: str | None = None


class ConsentOut(BaseModel):
    id: uuid.UUID
    consent_type: str
    policy_version: str
    is_granted: bool
    jurisdiction: str | None
    withdrawn_at: datetime | None
    created_at: datetime

    class Config:
        from_attributes = True


class DataExportRequestOut(BaseModel):
    id: uuid.UUID
    status: str
    export_format: str
    requested_at: datetime
    response_deadline_at: datetime | None

    class Config:
        from_attributes = True


VALID_CONSENT_TYPES = {
    "terms_of_service",
    "privacy_policy",
    "data_processing",
    "analytics",
    "marketing_communications",
}


@router.post(
    "/",
    response_model=ConsentOut,
    status_code=status.HTTP_201_CREATED,
    summary="Record or update a consent grant/withdrawal (PDPA/GDPR)",
)
async def record_consent(
    request: Request, body: ConsentGrantRequest, current_user: CurrentUser, db: DB
):
    if body.consent_type not in VALID_CONSENT_TYPES:
        logger.warning("Consent record rejected - invalid consent_type", consent_type=body.consent_type)
        raise ApiError(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"consent_type must be one of: {', '.join(sorted(VALID_CONSENT_TYPES))}",
            error_code=ErrorCode.INVALID_CONSENT_TYPE,
        )

    record = ConsentRecord(
        user_id=current_user.id,
        consent_type=body.consent_type,
        policy_version=CURRENT_POLICY_VERSION,
        is_granted=body.is_granted,
        ip_address=request.client.host if request.client else None,
        user_agent=request.headers.get("user-agent"),
        jurisdiction=body.jurisdiction or _detect_jurisdiction(request),
        withdrawn_at=None if body.is_granted else datetime.now(timezone.utc),
    )
    db.add(record)
    await db.commit()
    await db.refresh(record)
    logger.info(
        "Consent recorded",
        user_id=str(current_user.id),
        consent_type=body.consent_type,
        is_granted=body.is_granted,
        jurisdiction=record.jurisdiction,
    )
    return ConsentOut.model_validate(record)


@router.get(
    "/",
    response_model=list[ConsentOut],
    summary="List all consent records for the current user",
)
async def list_consents(current_user: CurrentUser, db: DB):
    records = (
        await db.scalars(
            select(ConsentRecord)
            .where(ConsentRecord.user_id == current_user.id)
            .order_by(ConsentRecord.created_at.desc())
        )
    ).all()
    return [ConsentOut.model_validate(r) for r in records]


@router.post(
    "/data-export",
    response_model=DataExportRequestOut,
    status_code=status.HTTP_201_CREATED,
    summary="Request a full data export - GDPR Article 20 right to data portability",
)
async def request_data_export(
    request: Request, current_user: CurrentUser, db: DB
):
    from datetime import timedelta

    # Check for a pending export already in flight
    existing = await db.scalar(
        select(DataExportRequest).where(
            DataExportRequest.user_id == current_user.id,
            DataExportRequest.status.in_(["pending", "processing"]),
        )
    )
    if existing:
        logger.info("Data export request rejected - one already in progress", user_id=str(current_user.id))
        raise ApiError(
            status_code=status.HTTP_409_CONFLICT,
            detail="A data export is already in progress. You will be notified when it is ready.",
            error_code=ErrorCode.DATA_EXPORT_IN_PROGRESS,
        )

    deadline = datetime.now(timezone.utc) + timedelta(days=30)
    export_req = DataExportRequest(
        user_id=current_user.id,
        export_format="json",
        status="pending",
        scope="all",
        requested_at=datetime.now(timezone.utc),
        response_deadline_at=deadline,
    )
    db.add(export_req)
    await db.commit()
    await db.refresh(export_req)
    logger.info("Data export requested", user_id=str(current_user.id), request_id=str(export_req.id), deadline=deadline.isoformat())
    return DataExportRequestOut.model_validate(export_req)


@router.get(
    "/data-export",
    response_model=list[DataExportRequestOut],
    summary="List all data export requests for the current user",
)
async def list_data_exports(current_user: CurrentUser, db: DB):
    records = (
        await db.scalars(
            select(DataExportRequest)
            .where(DataExportRequest.user_id == current_user.id)
            .order_by(DataExportRequest.requested_at.desc())
        )
    ).all()
    return [DataExportRequestOut.model_validate(r) for r in records]


def _detect_jurisdiction(request: Request) -> str:
    """Best-effort jurisdiction detection from request headers."""
    cf_country = request.headers.get("cf-ipcountry", "").upper()
    eu_countries = {
        "AT", "BE", "BG", "CY", "CZ", "DE", "DK", "EE", "ES", "FI",
        "FR", "GR", "HR", "HU", "IE", "IT", "LT", "LU", "LV", "MT",
        "NL", "PL", "PT", "RO", "SE", "SI", "SK",
    }
    if cf_country == "PK":
        return "PK"
    if cf_country in eu_countries:
        return "EU"
    if cf_country == "US":
        return "US"
    return cf_country or "UNKNOWN"
