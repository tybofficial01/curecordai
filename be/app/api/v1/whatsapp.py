"""
Meta WhatsApp Cloud API webhook. Every inbound event lands here first; see project plan
"Architecture overview" for the full decision tree this implements: signature verify -> dedupe
-> phone match -> confirmed-binding gate -> fast ack -> background processing.
Registered standalone (not behind CurrentUser/DB auth deps) since Meta, not our own frontend,
calls this endpoint - request-level trust comes entirely from the HMAC signature check below.
"""
from datetime import datetime, timedelta, timezone

import structlog
from fastapi import APIRouter, BackgroundTasks, Query, Request, Response, status
from sqlalchemy import func, select

from app.config import settings
from app.database import AsyncSessionLocal
from app.models.whatsapp import WhatsAppInboundMessage
from app.services.whatsapp_binding import (
    get_or_create_binding,
    issue_confirmation_challenge,
    normalize_wa_number,
    resolve_user,
    try_confirm,
)
from app.services.whatsapp_service import verify_webhook_signature, whatsapp_service
from app.tasks.process_whatsapp_message import process_whatsapp_message

logger = structlog.get_logger()

router = APIRouter(prefix="/whatsapp", tags=["whatsapp"])

_ONBOARDING_MESSAGE = (
    "Hi! This number isn't linked to a CurecordAI account yet. Sign up or log in with this "
    "phone number at curecordai.com to use the WhatsApp assistant."
)


@router.get("/webhook")
async def verify_webhook(
    hub_mode: str = Query(..., alias="hub.mode"),
    hub_verify_token: str = Query(..., alias="hub.verify_token"),
    hub_challenge: str = Query(..., alias="hub.challenge"),
):
    """One-time GET handshake Meta performs when the webhook URL is registered."""
    if hub_mode == "subscribe" and hub_verify_token == settings.META_WA_VERIFY_TOKEN and settings.META_WA_VERIFY_TOKEN:
        return Response(content=hub_challenge, media_type="text/plain")
    logger.warning("WhatsApp webhook verification failed")
    return Response(status_code=status.HTTP_403_FORBIDDEN)


@router.post("/webhook")
async def receive_webhook(request: Request, background_tasks: BackgroundTasks):
    raw_body = await request.body()
    signature = request.headers.get("X-Hub-Signature-256")
    if not verify_webhook_signature(raw_body, signature):
        logger.warning("WhatsApp webhook signature verification failed")
        return Response(status_code=status.HTTP_401_UNAUTHORIZED)

    payload = await request.json()

    for entry in payload.get("entry", []):
        for change in entry.get("changes", []):
            value = change.get("value", {})
            for message in value.get("messages", []):
                await _handle_one_message(message, background_tasks)

    # Always 200 once the signature is valid, regardless of per-message outcome - Meta retries
    # a non-200 response, which would re-deliver every message in the batch, not just a failed one.
    return Response(status_code=status.HTTP_200_OK)


async def _handle_one_message(message: dict, background_tasks: BackgroundTasks) -> None:
    wa_message_id = message.get("id")
    sender_raw = message.get("from")
    msg_type = message.get("type")
    if not wa_message_id or not sender_raw or not msg_type:
        return
    sender = normalize_wa_number(sender_raw)

    async with AsyncSessionLocal() as db:
        existing = await db.scalar(
            select(WhatsAppInboundMessage.id).where(WhatsAppInboundMessage.wa_message_id == wa_message_id)
        )
        if existing:
            logger.debug("WhatsApp message already recorded - skipping (Meta retry)", wa_message_id=wa_message_id)
            return

        user = await resolve_user(db, sender)
        if not user:
            db.add(WhatsAppInboundMessage(
                wa_message_id=wa_message_id, sender_wa_number=sender, message_type=msg_type, status="completed",
            ))
            await db.commit()
            await whatsapp_service.send_text(sender, _ONBOARDING_MESSAGE, wa_message_id)
            return

        binding = await get_or_create_binding(db, user, sender)

        if not binding.is_confirmed:
            inbound = WhatsAppInboundMessage(
                wa_message_id=wa_message_id, user_id=user.id, sender_wa_number=sender,
                message_type=msg_type, status="completed",
            )
            db.add(inbound)
            await db.commit()
            await _handle_unconfirmed_binding(db, binding, user, message, sender, wa_message_id)
            return

        if await _rate_limited(db, user.id):
            await whatsapp_service.send_text(
                sender, "You're sending messages a bit fast - please wait a moment and try again.", wa_message_id,
            )
            return

        inbound = WhatsAppInboundMessage(
            wa_message_id=wa_message_id, user_id=user.id, sender_wa_number=sender,
            message_type=msg_type, status="received",
        )
        db.add(inbound)
        await db.commit()
        await db.refresh(inbound)

        background_tasks.add_task(
            process_whatsapp_message, str(inbound.id), str(user.id), sender, message,
        )


async def _handle_unconfirmed_binding(db, binding, user, message: dict, sender: str, wa_message_id: str) -> None:
    """Never touches records/chat/AI - this is the pre-access gate (project plan 'Security /
    binding - hardened two-step model')."""
    if binding.pending_code_hash and message.get("type") == "text":
        submitted = message["text"]["body"]
        if await try_confirm(db, binding, submitted):
            await whatsapp_service.send_text(
                sender, "You're confirmed! You can now ask about your records, request documents, or just chat.",
                wa_message_id,
            )
            return
        await whatsapp_service.send_text(
            sender, "That code didn't match. Reply with the confirmation code we emailed you, or wait for a new one.",
            wa_message_id,
        )
        return

    sent = await issue_confirmation_challenge(db, binding, user)
    if sent:
        await whatsapp_service.send_text(
            sender,
            f"To confirm this is you, we've emailed a confirmation code to your account email. "
            f"Reply with that code here within {settings.WA_CONFIRMATION_CODE_EXPIRE_MINUTES} minutes.",
            wa_message_id,
        )
    else:
        await whatsapp_service.send_text(
            sender,
            "We couldn't send a confirmation code - please verify your email address in the CurecordAI app first, "
            "then message us again here.",
            wa_message_id,
        )


async def _rate_limited(db, user_id) -> bool:
    """DB-backed per-user rate check (reuses the dedupe/audit table already written on every
    inbound message) rather than a new counter store - keeps this additive, no new infra."""
    window_start = datetime.now(timezone.utc) - timedelta(minutes=1)
    count = await db.scalar(
        select(func.count(WhatsAppInboundMessage.id)).where(
            WhatsAppInboundMessage.user_id == user_id,
            WhatsAppInboundMessage.created_at >= window_start,
        )
    )
    return (count or 0) >= settings.RATE_LIMIT_WHATSAPP_PER_MINUTE
