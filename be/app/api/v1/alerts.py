import uuid
from datetime import datetime, timezone

import structlog
from fastapi import APIRouter, HTTPException, Query, status
from pydantic import BaseModel, ConfigDict
from sqlalchemy import select, tuple_, update

from app.dependencies import CurrentUser, DB
from app.models.alerts import Alert

logger = structlog.get_logger()

router = APIRouter(prefix="/alerts", tags=["alerts"])


class AlertOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    user_id: uuid.UUID
    title: str
    message: str
    alert_type: str
    priority: str
    category: str
    is_read: bool
    read_at: datetime | None
    is_dismissed: bool
    linked_entity_type: str | None
    linked_entity_id: uuid.UUID | None
    created_at: datetime


@router.get("", response_model=list[AlertOut])
async def list_alerts(
    current_user: CurrentUser,
    db: DB,
    unread_only: bool = False,
    priority: str | None = None,
    limit: int = Query(50, le=200),
    before_created_at: datetime | None = None,
    before_id: uuid.UUID | None = None,
):
    """
    Cursor pagination: pass the `created_at`/`id` of the last item from the previous page
    (both already present on every AlertOut) to fetch the next one. Avoids OFFSET, which
    forces Postgres to scan and discard every preceding row on every page.
    """
    q = select(Alert).where(
        Alert.user_id == current_user.id,
        Alert.is_deleted == False,  # noqa: E712
        Alert.is_dismissed == False,  # noqa: E712
    )
    if unread_only:
        q = q.where(Alert.is_read == False)  # noqa: E712
    if priority:
        q = q.where(Alert.priority == priority)
    if before_created_at is not None and before_id is not None:
        # Tie-break on id since created_at alone isn't guaranteed unique.
        q = q.where(tuple_(Alert.created_at, Alert.id) < tuple_(before_created_at, before_id))

    alerts = (await db.scalars(
        q.order_by(Alert.created_at.desc(), Alert.id.desc()).limit(limit)
    )).all()
    return [AlertOut.model_validate(a) for a in alerts]


@router.get("/unread-count")
async def unread_count(current_user: CurrentUser, db: DB):
    from sqlalchemy import func as sqlfunc
    count = await db.scalar(
        select(sqlfunc.count()).select_from(Alert).where(
            Alert.user_id == current_user.id,
            Alert.is_read == False,  # noqa: E712
            Alert.is_deleted == False,  # noqa: E712
            Alert.is_dismissed == False,  # noqa: E712
        )
    )
    return {"unread_count": count or 0}


@router.post("/{alert_id}/read", status_code=status.HTTP_204_NO_CONTENT)
async def mark_read(alert_id: uuid.UUID, current_user: CurrentUser, db: DB):
    await db.execute(
        update(Alert)
        .where(Alert.id == alert_id, Alert.user_id == current_user.id)
        .values(is_read=True, read_at=datetime.now(timezone.utc))
    )
    await db.commit()
    logger.debug("Alert marked read", alert_id=str(alert_id), user_id=str(current_user.id))


@router.post("/read-all", status_code=status.HTTP_204_NO_CONTENT)
async def mark_all_read(current_user: CurrentUser, db: DB):
    now = datetime.now(timezone.utc)
    result = await db.execute(
        update(Alert)
        .where(Alert.user_id == current_user.id, Alert.is_read == False)  # noqa: E712
        .values(is_read=True, read_at=now)
    )
    await db.commit()
    logger.info("All alerts marked read", user_id=str(current_user.id), count=result.rowcount)


@router.post("/{alert_id}/dismiss", status_code=status.HTTP_204_NO_CONTENT)
async def dismiss_alert(alert_id: uuid.UUID, current_user: CurrentUser, db: DB):
    await db.execute(
        update(Alert)
        .where(Alert.id == alert_id, Alert.user_id == current_user.id)
        .values(is_dismissed=True, dismissed_at=datetime.now(timezone.utc))
    )
    await db.commit()
    logger.debug("Alert dismissed", alert_id=str(alert_id), user_id=str(current_user.id))
