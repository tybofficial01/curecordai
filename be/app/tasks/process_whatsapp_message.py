"""
Background orchestrator for one confirmed-and-bound WhatsApp message: routes by message type
to document upload (reuses the existing process_record pipeline unchanged), voice transcription,
or the tool-calling agent. Runs via FastAPI BackgroundTasks after the webhook has already
returned 200 to Meta - mirrors tasks/process_record.py's "own DB session" pattern.
"""
import uuid

import structlog
from sqlalchemy import select

from app.database import AsyncSessionLocal
from app.models.records import MedicalRecord
from app.models.whatsapp import WhatsAppBinding, WhatsAppInboundMessage
from app.services.chat_reply import generate_chat_reply
from app.services.s3_service import s3_service
from app.services.soniox_service import SonioxTranscriptionError, transcribe_audio
from app.services.whatsapp_agent import (
    get_or_create_active_session,
    get_saved_language,
    handle_interactive_reply,
    is_switch_profile_command,
    run_agent_turn,
    send_profile_switch_menu,
)
from app.services.whatsapp_service import whatsapp_service
from app.tasks.process_record import process_record

logger = structlog.get_logger()


async def process_whatsapp_message(
    inbound_message_id: str, user_id: str, sender_wa_number: str, message: dict,
) -> None:
    async with AsyncSessionLocal() as db:
        inbound = await db.get(WhatsAppInboundMessage, uuid.UUID(inbound_message_id))
        if not inbound:
            return
        inbound.status = "processing"
        await db.commit()

        try:
            binding = await db.scalar(
                select(WhatsAppBinding).where(
                    WhatsAppBinding.user_id == uuid.UUID(user_id),
                    WhatsAppBinding.wa_phone_number == sender_wa_number,
                    WhatsAppBinding.superseded_at.is_(None),
                )
            )
            if not binding or not binding.is_confirmed:
                # Confirmation state can't have changed mid-flight given the webhook already
                # gated on it, but never proceed to record/chat access without re-checking.
                inbound.status = "failed"
                inbound.error_message = "binding not confirmed"
                await db.commit()
                return

            msg_type = message.get("type")
            wa_message_id = message["id"]

            if msg_type == "text":
                text = message["text"]["body"]
                if is_switch_profile_command(text):
                    await send_profile_switch_menu(db, binding, sender_wa_number, wa_message_id)
                else:
                    await run_agent_turn(db, binding, text, sender_wa_number, wa_message_id)

            elif msg_type == "interactive":
                interactive = message.get("interactive", {})
                list_reply = interactive.get("list_reply")
                if list_reply:
                    await handle_interactive_reply(db, binding, list_reply["id"], sender_wa_number, wa_message_id)
                else:
                    await whatsapp_service.send_text(sender_wa_number, "Sorry, I didn't catch that selection.", wa_message_id)

            elif msg_type == "audio":
                await _handle_voice_note(db, binding, message, sender_wa_number, wa_message_id)

            elif msg_type in ("image", "document"):
                await _handle_document_upload(db, binding, message, msg_type, sender_wa_number, wa_message_id)

            else:
                await whatsapp_service.send_text(
                    sender_wa_number,
                    "I can only handle text, voice notes, images, and PDF/document uploads right now.",
                    wa_message_id,
                )

            inbound.status = "completed"
        except Exception as exc:
            logger.error(
                "WhatsApp message processing failed", inbound_message_id=inbound_message_id, error=str(exc), exc_info=True,
            )
            inbound.status = "failed"
            inbound.error_message = str(exc)[:500]
            try:
                await whatsapp_service.send_text(
                    sender_wa_number,
                    "Sorry, something went wrong processing that. Please try again in a moment.",
                    message.get("id"),
                )
            except Exception:
                logger.warning("Failed to send WhatsApp error notice", inbound_message_id=inbound_message_id)
        await db.commit()


async def _handle_voice_note(db, binding, message, to_wa_number: str, wa_message_id: str) -> None:
    media = message["audio"]
    resolved = await whatsapp_service.resolve_media_url(media["id"])
    if resolved is None:
        await whatsapp_service.send_text(to_wa_number, "Voice notes aren't available in this environment yet.", wa_message_id)
        return
    media_url, mime_type = resolved
    audio_bytes = await whatsapp_service.download_media(media_url)

    try:
        result = await transcribe_audio(audio_bytes, mime_type or media.get("mime_type", "audio/ogg"))
    except SonioxTranscriptionError as exc:
        logger.warning("Voice note transcription failed", error=str(exc))
        await whatsapp_service.send_text(
            to_wa_number, "Sorry, I couldn't understand that voice note - could you try typing your message instead?", wa_message_id,
        )
        return

    if not result["text"].strip():
        await whatsapp_service.send_text(to_wa_number, "I couldn't make out that voice note - could you try again?", wa_message_id)
        return

    await run_agent_turn(db, binding, result["text"], to_wa_number, wa_message_id)


async def _handle_document_upload(db, binding, message, msg_type: str, to_wa_number: str, wa_message_id: str) -> None:
    media = message[msg_type]
    resolved = await whatsapp_service.resolve_media_url(media["id"])
    if resolved is None:
        await whatsapp_service.send_text(to_wa_number, "Document upload isn't available in this environment yet.", wa_message_id)
        return
    media_url, resolved_mime = resolved
    mime_type = media.get("mime_type", resolved_mime)
    file_bytes = await whatsapp_service.download_media(media_url)

    active_session = await get_or_create_active_session(db, binding)
    file_name = media.get("filename") or f"whatsapp_upload_{wa_message_id}"
    object_key = s3_service.generate_object_key(binding.user_id, "records/whatsapp_upload", file_name)

    uploaded = await s3_service.upload_bytes(object_key, file_bytes, mime_type)
    if not uploaded:
        await whatsapp_service.send_text(to_wa_number, "Sorry, that upload failed. Please try sending it again.", wa_message_id)
        return

    record = MedicalRecord(
        user_id=binding.user_id,
        family_member_id=active_session.family_member_id,
        title="Untitled",
        record_type="other",
        file_key=object_key,
        file_name=file_name,
        file_mime_type=mime_type,
        file_size_bytes=len(file_bytes),
        processing_status="pending",
    )
    db.add(record)
    await db.commit()
    await db.refresh(record)

    caption = (media.get("caption") or "").strip()

    await whatsapp_service.send_text(
        to_wa_number,
        "Got it - processing your document now, I'll let you know once it's saved.",
        wa_message_id,
    )
    await process_record(str(record.id))

    await db.refresh(record)
    if record.processing_status != "completed":
        await whatsapp_service.send_text(
            to_wa_number,
            record.processing_error or "That document couldn't be processed - please check it's a genuine medical record.",
            wa_message_id,
        )
        return

    if not caption:
        await whatsapp_service.send_text(to_wa_number, f"Saved: \"{record.title}\".", wa_message_id)
        return

    # A caption sent along with the upload (e.g. "what does this show?") is a question about
    # exactly this document - answer it grounded on everything just extracted from it, the same
    # attached-record path the webapp chat uses when a patient tags a document to a question,
    # rather than silently dropping the caption and only confirming the save.
    language = await get_saved_language(db, binding.user_id)
    reply = await generate_chat_reply(db, active_session, caption, source_record_ids=[record.id], language=language)
    await whatsapp_service.send_text(
        to_wa_number, f"Saved: \"{record.title}\".\n\n{reply['content']}", wa_message_id,
    )
