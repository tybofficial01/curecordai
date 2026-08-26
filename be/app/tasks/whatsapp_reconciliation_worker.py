"""
In-process asyncio loop (mirrors medication_reminder_worker.py's no-Celery approach) that
retries WhatsApp messages stuck in "processing" - the mitigation for BackgroundTasks having no
built-in retry/durability (see project plan "Reliability hardening"). A message can get stuck
if the process restarts/crashes mid-task; without this, that document upload or chat reply is
silently lost with no signal to the user.
"""
import asyncio
from datetime import datetime, timedelta, timezone

import structlog
from sqlalchemy import select

from app.database import AsyncSessionLocal
from app.models.whatsapp import WhatsAppInboundMessage
from app.services.whatsapp_service import whatsapp_service

logger = structlog.get_logger()

_TICK_SECONDS = 120
_STUCK_THRESHOLD_MINUTES = 10


async def _reconcile_stuck_messages() -> None:
    """
    The original raw Meta payload for a message is never persisted (WhatsAppInboundMessage
    deliberately stores no message body/transcript - see its docstring on PHI-adjacent content),
    so a stuck row can't actually be re-driven through process_whatsapp_message from here -
    there is nothing durable to replay. This worker's only job is to make a lost message visible
    instead of silent: mark it failed and tell the user to resend.
    # ponytail: notify-and-ask-to-resend is the practical stopgap for BackgroundTasks having no
    # replay capability; true redrive needs the raw payload persisted (Celery+Redis job durability
    # is the upgrade path already flagged in the project plan).
    """
    cutoff = datetime.now(timezone.utc) - timedelta(minutes=_STUCK_THRESHOLD_MINUTES)
    async with AsyncSessionLocal() as db:
        stuck = (await db.scalars(
            select(WhatsAppInboundMessage).where(
                WhatsAppInboundMessage.status == "processing",
                WhatsAppInboundMessage.updated_at < cutoff,
            )
        )).all()

        for inbound in stuck:
            inbound.status = "failed"
            inbound.error_message = "Stuck in processing past threshold - never completed"
            await db.commit()
            logger.warning("WhatsApp message marked failed by reconciliation", inbound_id=str(inbound.id))
            try:
                await whatsapp_service.send_text(
                    inbound.sender_wa_number,
                    "Sorry, that message didn't go through - please resend it.",
                    None,
                )
            except Exception:
                logger.warning("Failed to notify user of WhatsApp processing failure", inbound_id=str(inbound.id))


async def run_whatsapp_reconciliation_worker(stop_event: asyncio.Event) -> None:
    logger.info("WhatsApp reconciliation worker started", tick_seconds=_TICK_SECONDS)
    while not stop_event.is_set():
        try:
            await _reconcile_stuck_messages()
        except Exception:
            logger.exception("WhatsApp reconciliation tick failed")
        try:
            await asyncio.wait_for(stop_event.wait(), timeout=_TICK_SECONDS)
        except asyncio.TimeoutError:
            pass
    logger.info("WhatsApp reconciliation worker stopped")
