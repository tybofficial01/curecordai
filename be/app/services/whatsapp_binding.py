"""
Phone -> account resolution and the confirmed-binding gate (see project plan "Security /
binding - hardened two-step model"). A WhatsApp number matching User.phone_number is only the
first, spoofable-at-the-telecom-layer signal; WhatsAppBinding.confirmed_at (set only after the
user proves control of the number via a code sent to their already-verified email) is the
actual access gate checked before any record/chat tool runs.
"""
import re
from datetime import datetime, timedelta, timezone

import structlog
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.core.security import generate_otp, hash_otp, verify_otp
from app.models.auth import User
from app.models.whatsapp import WhatsAppBinding
from app.services.twilio_service import twilio_service

logger = structlog.get_logger()


def normalize_wa_number(raw: str) -> str:
    """Meta sends the sender number without a leading '+' - always store/compare E.164 with one,
    matching whatsapp-docs.md's warning that an omitted '+' can misdirect a *sent* message; for
    matching against User.phone_number (which is stored with '+') this keeps both sides consistent."""
    digits = re.sub(r"[^\d]", "", raw)
    logger.debug("Normalized WhatsApp number", raw=raw, digits=digits)
    return f"+{digits}"


async def resolve_user(db: AsyncSession, wa_number: str) -> User | None:
    res = await db.scalar(
        select(User).where(
            User.phone_number == wa_number,
            User.is_phone_verified == True,  # noqa: E712
            User.is_active == True,  # noqa: E712
            User.is_deleted == False,  # noqa: E712
        )
    )
    logger.debug("Resolved WhatsApp sender", user_id=str(res.id) if res else None)
    return res


async def get_or_create_binding(db: AsyncSession, user: User, wa_number: str) -> WhatsAppBinding:
    binding = await db.scalar(
        select(WhatsAppBinding).where(
            WhatsAppBinding.user_id == user.id,
            WhatsAppBinding.wa_phone_number == wa_number,
            WhatsAppBinding.superseded_at.is_(None),
        )
    )
    if binding:
        return binding
    binding = WhatsAppBinding(user_id=user.id, wa_phone_number=wa_number)
    db.add(binding)
    await db.commit()
    await db.refresh(binding)
    return binding


async def issue_confirmation_challenge(db: AsyncSession, binding: WhatsAppBinding, user: User) -> bool:
    """Sends a one-time code to the user's already-verified email. Returns True if a code was
    (or, in dev mode, would be) sent - False if the user has no verified channel to send to,
    in which case the caller must tell the patient to confirm via the app/web instead."""
    if not user.email or not user.is_email_verified:
        logger.warning("Cannot issue WhatsApp confirmation - no verified email on file", user_id=str(user.id))
        return False

    code = generate_otp(settings.OTP_LENGTH)
    binding.pending_code_hash = hash_otp(code)
    binding.pending_code_expires_at = datetime.now(timezone.utc) + timedelta(
        minutes=settings.WA_CONFIRMATION_CODE_EXPIRE_MINUTES
    )
    await db.commit()

    sent = await twilio_service.send_otp_email(
        user.email, code, purpose="confirm WhatsApp access to your CurecordAI account"
    )
    if not sent:
        # Don't leave the patient stuck believing a code is on its way when it never sent
        # (e.g. SMTP misconfigured/down) - clear the pending challenge so a retry is possible
        # instead of silently expiring after WA_CONFIRMATION_CODE_EXPIRE_MINUTES.
        binding.pending_code_hash = None
        binding.pending_code_expires_at = None
        await db.commit()
        logger.error("Failed to send WhatsApp confirmation email", user_id=str(user.id))
        return False
    return True


async def try_confirm(db: AsyncSession, binding: WhatsAppBinding, submitted_code: str) -> bool:
    if not binding.pending_code_hash or not binding.pending_code_expires_at:
        return False
    if datetime.now(timezone.utc) > binding.pending_code_expires_at:
        return False
    if not verify_otp(submitted_code.strip(), binding.pending_code_hash):
        return False

    binding.confirmed_at = datetime.now(timezone.utc)
    binding.confirmation_method = "email_code"
    binding.pending_code_hash = None
    binding.pending_code_expires_at = None
    await db.commit()
    return True
