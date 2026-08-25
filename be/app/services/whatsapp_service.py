"""
Meta WhatsApp Cloud API client - plain REST/JSON over httpx, no vendor SDK (Meta doesn't
publish one), mirrors the shape of TwilioService (singleton, dev-mode console fallback).
See /whatsapp-docs.md for the reference this was built against.
"""
import hashlib
import hmac
import re

import httpx
import structlog

from app.config import settings

logger = structlog.get_logger()

# WhatsApp Cloud API limits (see whatsapp-docs.md section 5): oversized/mismatched media are
# rejected by Meta with error codes 131052/131053 - checking client-side avoids a wasted round
# trip and lets the caller choose a fallback message type (image -> document) before sending.
MAX_IMAGE_BYTES = 5 * 1024 * 1024
MAX_DOCUMENT_BYTES = 100 * 1024 * 1024
MAX_TEXT_CHARS = 4096

_UNSAFE_FILENAME_CHARS = re.compile(r"[^\w.\-]")


def verify_webhook_signature(raw_body: bytes, signature_header: str | None) -> bool:
    """
    HMAC-SHA256 of the raw body using the app secret, constant-time compared against
    X-Hub-Signature-256 ("sha256=<hex>"). This is the trust boundary for every inbound webhook -
    callers must reject (401) before parsing the payload at all if this returns False.
    """
    if not signature_header or not signature_header.startswith("sha256="):
        return False
    if not settings.META_WA_APP_SECRET:
        logger.error("META_WA_APP_SECRET not configured - refusing to accept webhook")
        return False
    expected = hmac.new(
        settings.META_WA_APP_SECRET.encode("utf-8"), raw_body, hashlib.sha256
    ).hexdigest()
    provided = signature_header[len("sha256="):]
    return hmac.compare_digest(expected, provided)


class WhatsAppService:
    def __init__(self) -> None:
        self._base_url = f"https://graph.facebook.com/{settings.META_WA_API_VERSION}"

    @property
    def _configured(self) -> bool:
        return bool(settings.META_WA_ACCESS_TOKEN and settings.META_WA_PHONE_NUMBER_ID)

    @property
    def _headers(self) -> dict:
        return {"Authorization": f"Bearer {settings.META_WA_ACCESS_TOKEN}"}

    async def _post_message(self, payload: dict) -> dict | None:
        if not self._configured:
            print("============================================")
            print(f"DEV MODE WHATSAPP SEND: {payload}")
            print("============================================")
            logger.info("DEV MODE - WhatsApp message printed to terminal", to=payload.get("to"))
            return None
        url = f"{self._base_url}/{settings.META_WA_PHONE_NUMBER_ID}/messages"
        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                resp = await client.post(url, headers=self._headers, json=payload)
                if resp.is_error:
                    logger.error("WhatsApp send failed", status_code=resp.status_code, body=resp.text, to=payload.get("to"))
                resp.raise_for_status()
                return resp.json()
        except httpx.HTTPError as exc:
            # A failed outbound send (expired token, transient Graph API error, rate limit) must
            # never crash the request/background task it's a side effect of - the caller already
            # did its real work (chat answer computed, document uploaded, etc.); losing the
            # WhatsApp notification is a degraded outcome, not a reason to fail the whole flow.
            logger.error("WhatsApp send raised", error=str(exc), to=payload.get("to"))
            return None

    def _context(self, reply_to_wa_message_id: str | None) -> dict:
        """Meta's native quoted-reply field - threads the reply under the specific inbound
        message it answers, so out-of-order background replies stay unambiguous."""
        return {"context": {"message_id": reply_to_wa_message_id}} if reply_to_wa_message_id else {}

    async def send_text(self, to: str, body: str, reply_to_wa_message_id: str | None = None) -> dict | None:
        """Splits on a paragraph/sentence boundary near MAX_TEXT_CHARS rather than sending
        oversized text that Meta would reject outright."""
        chunks = _chunk_text(body, MAX_TEXT_CHARS)
        last: dict | None = None
        for chunk in chunks:
            payload = {
                "messaging_product": "whatsapp",
                "to": to,
                "type": "text",
                "text": {"body": chunk},
                **self._context(reply_to_wa_message_id),
            }
            last = await self._post_message(payload)
        return last

    async def send_media(
        self,
        to: str,
        link: str,
        kind: str,  # "image" | "document"
        filename: str | None = None,
        caption: str | None = None,
        reply_to_wa_message_id: str | None = None,
    ) -> dict | None:
        media_obj: dict = {"link": link}
        if caption:
            media_obj["caption"] = caption
        if kind == "document" and filename:
            media_obj["filename"] = _UNSAFE_FILENAME_CHARS.sub("_", filename)[:240]
        payload = {
            "messaging_product": "whatsapp",
            "to": to,
            "type": kind,
            kind: media_obj,
            **self._context(reply_to_wa_message_id),
        }
        return await self._post_message(payload)

    async def send_interactive_list(
        self,
        to: str,
        body_text: str,
        button_text: str,
        rows: list[dict],  # [{"id": ..., "title": ..., "description": ...}]
        header_text: str | None = None,
        reply_to_wa_message_id: str | None = None,
    ) -> dict | None:
        """Native tappable menu - the whole mechanism for zero-typing family-profile switching.
        Meta caps 10 rows per list; truncate rather than send a payload Meta will reject."""
        action = {"button": button_text[:20], "sections": [{"rows": rows[:10]}]}
        interactive: dict = {"type": "list", "body": {"text": body_text}, "action": action}
        if header_text:
            interactive["header"] = {"type": "text", "text": header_text[:60]}
        payload = {
            "messaging_product": "whatsapp",
            "to": to,
            "type": "interactive",
            "interactive": interactive,
            **self._context(reply_to_wa_message_id),
        }
        return await self._post_message(payload)

    async def resolve_media_url(self, media_id: str) -> tuple[str, str] | None:
        """GET /{media_id} -> temporary (5-min) download URL + mime_type. Must be fetched
        promptly - the URL expires quickly (whatsapp-docs.md section 5)."""
        if not self._configured:
            logger.info("DEV MODE - media resolve skipped", media_id=media_id)
            return None
        url = f"{self._base_url}/{media_id}"
        async with httpx.AsyncClient(timeout=15.0) as client:
            resp = await client.get(url, headers=self._headers)
            resp.raise_for_status()
            data = resp.json()
        return data["url"], data.get("mime_type", "")

    async def download_media(self, media_url: str) -> bytes:
        """The resolved media URL is itself bearer-token-authenticated - a plain unauthenticated
        fetch returns an error, not the file."""
        async with httpx.AsyncClient(timeout=60.0) as client:
            resp = await client.get(media_url, headers=self._headers)
            resp.raise_for_status()
            return resp.content


def _chunk_text(text: str, max_chars: int) -> list[str]:
    if len(text) <= max_chars:
        return [text]
    chunks = []
    remaining = text
    while remaining:
        if len(remaining) <= max_chars:
            chunks.append(remaining)
            break
        split_at = remaining.rfind("\n\n", 0, max_chars)
        if split_at < max_chars // 2:
            split_at = remaining.rfind(". ", 0, max_chars)
        if split_at < max_chars // 2:
            split_at = max_chars
        chunks.append(remaining[:split_at].rstrip())
        remaining = remaining[split_at:].lstrip()
    return chunks


whatsapp_service = WhatsAppService()
