import asyncio
import smtplib
from email.message import EmailMessage

import structlog
from twilio.rest import Client

from app.config import settings
from app.core.enums import Language
from app.services.email_templates import (
    OTP_PURPOSE_VERIFY_EMAIL,
    contact_form_forward_email,
    medication_reminder_email,
    otp_email,
)

logger = structlog.get_logger()

_OTP_SMS_BODIES: dict[Language, str] = {
    Language.EN: (
        "Your CurecordAI verification code is: {otp}. Valid for {minutes} minutes. "
        "Do not share this code."
    ),
    Language.UR: (
        "آپ کا CurecordAI تصدیقی کوڈ ہے: {otp}۔ یہ {minutes} منٹ کے لیے کارآمد ہے۔ "
        "یہ کوڈ کسی سے شیئر نہ کریں۔"
    ),
    Language.ROMAN_UR: (
        "Aap ka CurecordAI verification code hai: {otp}. Yeh {minutes} minute ke liye valid hai. "
        "Yeh code kisi ke saath share na karein."
    ),
}


class TwilioService:
    def __init__(self) -> None:
        self._client: Client | None = None

    @property
    def client(self) -> Client:
        if self._client is None:
            self._client = Client(settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN)
        return self._client

    async def send_otp_sms(self, phone_number: str, otp: str, language: Language = Language.EN) -> bool:
        """Send OTP via SMS, in `language`. Returns True on success."""
        logger.debug("send_otp_sms started", phone=phone_number, app_env=settings.APP_ENV, language=language.value)
        # TODO: Set APP_ENV=production to enable real SMS via Twilio
        if settings.APP_ENV == "development":
            print("============================================")
            print(f"DEV MODE OTP - Phone: {phone_number} - OTP: {otp}")
            print("============================================")
            logger.info("DEV MODE - OTP printed to terminal", phone=phone_number)
            return True
        else:
            try:
                body = _OTP_SMS_BODIES[language].format(otp=otp, minutes=settings.OTP_EXPIRE_MINUTES)
                message = self.client.messages.create(
                    body=body,
                    from_=settings.TWILIO_PHONE_NUMBER,
                    to=phone_number,
                )
                logger.info("OTP SMS sent", sid=message.sid, phone=phone_number)
                return True
            except Exception as exc:
                logger.error("Failed to send OTP SMS", phone=phone_number, error=str(exc))
                return False

    async def send_otp_email(
        self,
        email: str,
        otp: str,
        purpose: str = OTP_PURPOSE_VERIFY_EMAIL,
        language: Language = Language.EN,
    ) -> bool:
        """Send OTP via SMTP email, in `language`. Returns True on success."""
        logger.debug("send_otp_email started", email=email, language=language.value)
        try:
            await asyncio.to_thread(self._send_otp_email_sync, email, otp, purpose, language)
            logger.info("OTP email sent", email=email)
            return True
        except Exception as exc:
            logger.error("Failed to send OTP email", email=email, error=str(exc))
            return False

    def _send_otp_email_sync(self, email: str, otp: str, purpose: str, language: Language) -> None:
        subject, plain_body, html_body = otp_email(
            otp, settings.OTP_EXPIRE_MINUTES, purpose, language=language
        )
        message = EmailMessage()
        message["Subject"] = subject
        message["From"] = f"{settings.SES_FROM_NAME} <{settings.EMAIL_HOST_USER}>"
        message["To"] = email
        message.set_content(plain_body)
        message.add_alternative(html_body, subtype="html")

        with smtplib.SMTP(settings.EMAIL_HOST, settings.EMAIL_PORT, timeout=10) as server:
            if settings.EMAIL_USE_TLS:
                server.starttls()
            server.login(settings.EMAIL_HOST_USER, settings.EMAIL_HOST_PASSWORD)
            server.send_message(message)

    async def send_contact_message(self, name: str, email: str, message_body: str) -> bool:
        """Forward a public contact-form submission to the support inbox. Returns True on success."""
        logger.debug("send_contact_message started", email=email)
        try:
            await asyncio.to_thread(self._send_contact_message_sync, name, email, message_body)
            logger.info("Contact form message sent", email=email)
            return True
        except Exception as exc:
            logger.error("Failed to send contact form message", email=email, error=str(exc))
            return False

    async def send_medication_reminder_email(
        self,
        email: str,
        recipient_label: str | None,
        medication_name: str,
        dosage: str | None,
        scheduled_local_time: str,
        language: Language = Language.EN,
    ) -> bool:
        """Send a medication dose reminder email, in `language`. Returns True on success."""
        logger.debug(
            "send_medication_reminder_email started",
            email=email, medication_name=medication_name, language=language.value,
        )
        try:
            await asyncio.to_thread(
                self._send_medication_reminder_email_sync,
                email, recipient_label, medication_name, dosage, scheduled_local_time, language,
            )
            logger.info("Medication reminder email sent", email=email, medication_name=medication_name)
            return True
        except Exception as exc:
            logger.error("Failed to send medication reminder email", email=email, error=str(exc))
            return False

    def _send_medication_reminder_email_sync(
        self,
        email: str,
        recipient_label: str | None,
        medication_name: str,
        dosage: str | None,
        scheduled_local_time: str,
        language: Language,
    ) -> None:
        subject, plain_body, html_body = medication_reminder_email(
            recipient_label, medication_name, dosage, scheduled_local_time, language=language
        )
        message = EmailMessage()
        message["Subject"] = subject
        message["From"] = f"{settings.SES_FROM_NAME} <{settings.EMAIL_HOST_USER}>"
        message["To"] = email
        message.set_content(plain_body)
        message.add_alternative(html_body, subtype="html")

        with smtplib.SMTP(settings.EMAIL_HOST, settings.EMAIL_PORT, timeout=10) as server:
            if settings.EMAIL_USE_TLS:
                server.starttls()
            server.login(settings.EMAIL_HOST_USER, settings.EMAIL_HOST_PASSWORD)
            server.send_message(message)

    def _send_contact_message_sync(self, name: str, email: str, message_body: str) -> None:
        subject, plain_body, html_body = contact_form_forward_email(name, email, message_body)
        message = EmailMessage()
        message["Subject"] = subject
        message["From"] = f"{settings.SES_FROM_NAME} <{settings.EMAIL_HOST_USER}>"
        message["To"] = settings.CONTACT_INBOX_EMAIL
        message["Reply-To"] = email
        message.set_content(plain_body)
        message.add_alternative(html_body, subtype="html")

        with smtplib.SMTP(settings.EMAIL_HOST, settings.EMAIL_PORT, timeout=10) as server:
            if settings.EMAIL_USE_TLS:
                server.starttls()
            server.login(settings.EMAIL_HOST_USER, settings.EMAIL_HOST_PASSWORD)
            server.send_message(message)


twilio_service = TwilioService()
