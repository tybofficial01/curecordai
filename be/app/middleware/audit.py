"""
HIPAA §164.312(b) audit middleware.
Logs every request touching PHI to audit.audit_logs.
No PHI values stored - opaque IDs only.

This middleware creates its own DB session per audited request so it is not
dependent on the per-handler dependency-injected session, which is not
accessible from middleware context.
"""
import re
import time
import uuid
from typing import Callable

import structlog
from fastapi import Request, Response
from sqlalchemy import insert, text
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from starlette.background import BackgroundTask

from app.config import settings
from app.models.audit import AuditLog

logger = structlog.get_logger()

# Single engine shared across all audit writes (separate pool from app engine)
_audit_engine = create_async_engine(
    settings.DATABASE_URL,
    pool_size=3,
    max_overflow=2,
    pool_pre_ping=True,
    echo=False,
    connect_args={"server_settings": {"statement_timeout": "60000"}},
)
_AuditSession = async_sessionmaker(_audit_engine, class_=AsyncSession, expire_on_commit=False)

# Endpoints that access PHI and must be audited
PHI_RESOURCE_MAP: dict[str, str] = {
    "/api/v1/records": "medical_record",
    "/api/v1/conditions": "condition",
    "/api/v1/medication-requests": "medication_request",
    "/api/v1/medications": "medication_reminder",
    "/api/v1/observations": "observation",
    "/api/v1/allergies": "allergy_intolerance",
    "/api/v1/encounters": "encounter",
    "/api/v1/family": "family_member",
    "/api/v1/users/me": "user_profile",
    "/api/v1/ai": "ai_chat",
    "/api/v1/share": "doctor_share",
    "/api/v1/emergency": "emergency",
    "/api/v1/alerts": "alert",
    "/api/v1/consent": "consent",
}

ACTION_MAP: dict[str, str] = {
    "GET": "view",
    "POST": "create",
    "PATCH": "update",
    "PUT": "update",
    "DELETE": "delete",
}

# Path patterns that should map to "download" action regardless of HTTP method
_DOWNLOAD_RE = re.compile(r"/download$")
# Path patterns for "share" action
_SHARE_SCAN_RE = re.compile(r"/share/view/")


def _get_resource_type(path: str) -> str | None:
    for prefix, rtype in PHI_RESOURCE_MAP.items():
        if path.startswith(prefix):
            return rtype
    return None


def _extract_resource_id(path: str) -> uuid.UUID | None:
    """Extract a UUID path parameter from the URL if present."""
    # Match any UUID segment in the path
    match = re.search(
        r"/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})",
        path,
        re.IGNORECASE,
    )
    if match:
        try:
            return uuid.UUID(match.group(1))
        except ValueError:
            pass
    return None


def _get_action(method: str, path: str) -> str:
    if _DOWNLOAD_RE.search(path):
        return "download"
    if _SHARE_SCAN_RE.search(path):
        return "share_view"
    return ACTION_MAP.get(method, method.lower())


async def audit_middleware(request: Request, call_next: Callable) -> Response:
    start = time.time()
    response = await call_next(request)

    resource_type = _get_resource_type(request.url.path)
    if not resource_type:
        logger.debug("Audit middleware - path not PHI-mapped, skipping", path=request.url.path)
        return response

    # Actor info is set on request.state by the auth dependency (get_current_user)
    actor_user_id: uuid.UUID | None = getattr(request.state, "user_id", None)
    actor_role: str | None = getattr(request.state, "user_role", None)
    resource_owner_id: uuid.UUID | None = getattr(request.state, "resource_owner_id", None)

    # Derive resource_id from path parameters - avoids requiring routes to set it
    resource_id: uuid.UUID | None = (
        getattr(request.state, "resource_id", None)
        or _extract_resource_id(request.url.path)
    )

    action = _get_action(request.method, request.url.path)
    outcome = (
        "success" if response.status_code < 400
        else "unauthorized" if response.status_code == 401
        else "forbidden" if response.status_code == 403
        else "failure"
    )

    # Write to audit schema using a dedicated session - never raises (PHI access must not block).
    # Runs as a background task so it executes after the response is sent to the client,
    # instead of adding a second DB round trip to every PHI request's latency.
    async def _write_audit_log() -> None:
        try:
            async with _AuditSession() as db:
                await db.execute(insert(AuditLog).values(
                    actor_user_id=actor_user_id,
                    actor_role_snapshot=actor_role,
                    actor_ip=request.client.host if request.client else None,
                    actor_device_type=_parse_device_type(request.headers.get("user-agent", "")),
                    actor_user_agent=request.headers.get("user-agent"),
                    action=action,
                    resource_type=resource_type,
                    resource_id=resource_id,
                    resource_owner_user_id=resource_owner_id or actor_user_id,
                    http_method=request.method,
                    endpoint=request.url.path,
                    request_id=getattr(request.state, "request_id", None),
                    outcome_status=outcome,
                    http_status_code=response.status_code,
                ))
                await db.commit()
            logger.debug(
                "Audit log written",
                resource_type=resource_type,
                action=action,
                outcome=outcome,
                actor_user_id=str(actor_user_id) if actor_user_id else None,
            )
        except Exception as exc:
            # Never let audit failure surface to the caller - but make it visible for local debugging
            logger.error("Audit log write failed", resource_type=resource_type, error=str(exc), exc_info=True)

    # A route may have already attached its own background task(s) (e.g. FastAPI's
    # BackgroundTasks) - chain rather than clobber so ours doesn't drop theirs.
    existing_background = response.background

    async def _run_background() -> None:
        if existing_background is not None:
            await existing_background()
        await _write_audit_log()

    response.background = BackgroundTask(_run_background)
    return response


def _parse_device_type(user_agent: str) -> str:
    ua = user_agent.lower()
    if "android" in ua:
        return "android"
    if "iphone" in ua or "ipad" in ua or "ios" in ua:
        return "ios"
    if "mozilla" in ua or "chrome" in ua or "safari" in ua:
        return "web"
    return "api"
