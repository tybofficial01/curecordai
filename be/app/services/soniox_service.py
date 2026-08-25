"""
Soniox async transcription REST client - plain httpx, no SDK (matches openrouter.py style).

Verified against Soniox's live API reference (docs/api-reference/stt/files,
docs/api-reference/stt/transcriptions): base URL https://api.soniox.com, endpoints
POST /v1/files, POST /v1/transcriptions, GET /v1/transcriptions/{id},
GET /v1/transcriptions/{id}/transcript. POST /v1/transcriptions requires a `model` field
(no default) - "stt-async-preview" is Soniox's async file-transcription model - and
`enable_language_identification` must be set for per-token `language` to be populated.
"""
import asyncio

import httpx
import structlog

from app.config import settings

logger = structlog.get_logger()

_BASE_URL = "https://api.soniox.com/v1"
_POLL_INTERVAL_SECONDS = 2
_POLL_TIMEOUT_SECONDS = 60
# Voice notes only ever need to resolve to English or Urdu for this bot's downstream intent
# classification - constraining the hint set (rather than leaving it open to all 60+ languages)
# improves accuracy for Roman Urdu, which is phonetically ambiguous with English.
_LANGUAGE_HINTS = ["en", "ur"]


class SonioxTranscriptionError(Exception):
    pass


async def transcribe_audio(audio_bytes: bytes, mime_type: str) -> dict:
    """
    Uploads a voice-note recording and returns {"text": str, "language": str | None}.
    Returns an empty transcript (never raises) when SONIOX_API_KEY isn't configured, matching
    the dev-mode graceful-degradation pattern used by openrouter.get_embeddings.
    """
    if not settings.SONIOX_API_KEY:
        logger.warning("Soniox API key not configured - skipping transcription")
        return {"text": "", "language": None}

    headers = {"Authorization": f"Bearer {settings.SONIOX_API_KEY}"}

    async with httpx.AsyncClient(timeout=30.0) as client:
        upload_resp = await client.post(
            f"{_BASE_URL}/files",
            headers=headers,
            files={"file": ("voice_note", audio_bytes, mime_type)},
        )
        if upload_resp.is_error:
            logger.error("Soniox file upload failed", status_code=upload_resp.status_code, body=upload_resp.text)
        upload_resp.raise_for_status()
        file_id = upload_resp.json()["id"]

        create_resp = await client.post(
            f"{_BASE_URL}/transcriptions",
            headers=headers,
            json={
                "file_id": file_id,
                "model": "stt-async-preview",
                "language_hints": _LANGUAGE_HINTS,
                "enable_language_identification": True,
            },
        )
        create_resp.raise_for_status()
        transcription_id = create_resp.json()["id"]

        elapsed = 0
        while elapsed < _POLL_TIMEOUT_SECONDS:
            status_resp = await client.get(f"{_BASE_URL}/transcriptions/{transcription_id}", headers=headers)
            status_resp.raise_for_status()
            status_data = status_resp.json()
            status = status_data.get("status")
            if status == "completed":
                break
            if status == "error":
                raise SonioxTranscriptionError(status_data.get("error_message", "Soniox transcription failed"))
            await asyncio.sleep(_POLL_INTERVAL_SECONDS)
            elapsed += _POLL_INTERVAL_SECONDS
        else:
            raise SonioxTranscriptionError("Soniox transcription timed out")

        transcript_resp = await client.get(
            f"{_BASE_URL}/transcriptions/{transcription_id}/transcript", headers=headers
        )
        transcript_resp.raise_for_status()
        transcript_data = transcript_resp.json()

    text = transcript_data.get("text", "")
    detected_language = None
    tokens = transcript_data.get("tokens") or []
    if tokens:
        detected_language = tokens[0].get("language")

    logger.info("Voice note transcribed", chars=len(text), language=detected_language)
    return {"text": text, "language": detected_language}
