"""
Machine-readable error codes for client-facing API errors.

Why this exists
---------------
Per CLAUDE.md, API errors must stay generic and must never leak internals. That rule is
already satisfied across the app - but "generic" also meant "a hardcoded English sentence
with nothing a client can key off". A Flutter/Next.js client that wants to show the message
in Urdu or Roman Urdu has no reliable way to do that: matching on English prose is brittle
and breaks the moment the wording is edited server-side.

`ApiError` keeps the existing response shape byte-for-byte compatible - `detail` is still
the same plain English string, so anything already reading `detail` keeps working - and
adds a sibling `error_code` field the client maps to its own localized copy:

    {"detail": "Invalid OTP", "error_code": "otp_invalid"}

Applied across every endpoint that raises a client-facing HTTPException (auth/OTP, records,
profile, medications, family, sharing, emergency, ai_chat, consent, contact, and the shared
dependencies/scoping helpers). Never put internal detail (exception text, SQL, paths) into
either field.
"""
from typing import Any

from fastapi import HTTPException
from fastapi.responses import JSONResponse
from starlette.requests import Request


class ErrorCode:
    """Stable identifiers clients map to their own localized strings. Never renumber/rename
    an existing value - clients pin against these."""

    # Rate limiting / throttling
    OTP_RATE_LIMITED = "otp_rate_limited"

    # OTP + verification-code lifecycle
    OTP_NOT_FOUND = "otp_not_found"
    OTP_ATTEMPTS_EXCEEDED = "otp_attempts_exceeded"
    OTP_INVALID = "otp_invalid"
    OTP_DELIVERY_FAILED = "otp_delivery_failed"
    OTP_TOKEN_INVALID = "otp_token_invalid"

    # Account state / registration
    PHONE_NOT_REGISTERED = "phone_not_registered"
    PHONE_ALREADY_REGISTERED = "phone_already_registered"
    EMAIL_ALREADY_REGISTERED = "email_already_registered"
    EMAIL_TOKEN_INVALID = "email_token_invalid"
    EMAIL_TOKEN_MISMATCH = "email_token_mismatch"

    # Sign-in
    INVALID_CREDENTIALS = "invalid_credentials"
    ACCOUNT_LOCKED = "account_locked"
    ACCOUNT_DEACTIVATED = "account_deactivated"
    OAUTH_TOKEN_INVALID = "oauth_token_invalid"

    # Session / tokens
    REFRESH_TOKEN_INVALID = "refresh_token_invalid"
    REFRESH_TOKEN_EXPIRED = "refresh_token_expired"
    SESSION_USER_UNAVAILABLE = "session_user_unavailable"

    # Per-request auth (app/dependencies.py) - distinct from the sign-in/refresh codes
    # above, which cover the auth *flow*; these cover an already-issued token/session
    # failing on a later request.
    NOT_AUTHENTICATED = "not_authenticated"
    TOKEN_INVALID = "token_invalid"
    TOKEN_PAYLOAD_INVALID = "token_payload_invalid"
    SESSION_INVALID = "session_invalid"
    ROLE_REQUIRED = "role_required"
    ROLE_EXPIRED = "role_expired"

    # Cross-cutting "not found" / "not permitted" - shared across whichever endpoint
    # looks the resource up, so a client only needs one localized string per resource
    # type regardless of which call raised it.
    USER_NOT_FOUND = "user_not_found"
    PROFILE_NOT_FOUND = "profile_not_found"
    ACCESS_DENIED = "access_denied"
    OBJECT_KEY_REQUIRED = "object_key_required"
    FAMILY_MEMBER_NOT_FOUND = "family_member_not_found"
    FOLDER_NOT_FOUND = "folder_not_found"
    RECORD_NOT_FOUND = "record_not_found"
    CLINICAL_ENTITY_NOT_FOUND = "clinical_entity_not_found"
    EMERGENCY_CONTACT_NOT_FOUND = "emergency_contact_not_found"
    CHAT_SESSION_NOT_FOUND = "chat_session_not_found"
    SHARING_RECORD_NOT_FOUND = "sharing_record_not_found"

    # Records / upload
    INVALID_RECORD_TYPE = "invalid_record_type"
    UNSUPPORTED_FILE_TYPE = "unsupported_file_type"
    FILE_TOO_LARGE = "file_too_large"
    DUPLICATE_RECORD = "duplicate_record"

    # Medications
    MEDICATION_REMINDER_NOT_FOUND = "medication_reminder_not_found"
    INVALID_STATUS_FILTER = "invalid_status_filter"
    MEDICATION_REQUEST_ID_REQUIRED = "medication_request_id_required"
    SOURCE_MEDICATION_NOT_FOUND = "source_medication_not_found"
    DAYS_OF_WEEK_REQUIRED = "days_of_week_required"
    INTERVAL_DAYS_REQUIRED = "interval_days_required"

    # Sharing
    INVALID_SHARE_SCOPE = "invalid_share_scope"
    SHARE_SESSION_NOT_FOUND = "share_session_not_found"
    SHARE_LINK_INVALID = "share_link_invalid"
    DOCTOR_INSTRUCTIONS_REQUIRED = "doctor_instructions_required"
    INSTRUCTION_NOT_FOUND = "instruction_not_found"

    # Family
    INVALID_IMAGE_TYPE = "invalid_image_type"

    # Profile / avatar
    INVALID_AVATAR_TYPE = "invalid_avatar_type"
    AVATAR_TOO_LARGE = "avatar_too_large"
    AVATAR_UPLOAD_FAILED = "avatar_upload_failed"

    # Consent
    INVALID_CONSENT_TYPE = "invalid_consent_type"
    DATA_EXPORT_IN_PROGRESS = "data_export_in_progress"

    # Contact form
    CONTACT_MESSAGE_FAILED = "contact_message_failed"


class ApiError(HTTPException):
    """HTTPException that additionally carries a stable, client-mappable `error_code`.

    `detail` stays a plain string so the JSON response is a superset of the existing
    shape rather than a breaking change.
    """

    def __init__(
        self,
        status_code: int,
        detail: str,
        error_code: str,
        headers: dict[str, str] | None = None,
    ) -> None:
        super().__init__(status_code=status_code, detail=detail, headers=headers)
        self.error_code = error_code


async def api_error_handler(request: Request, exc: ApiError) -> JSONResponse:
    """Render ApiError as {"detail": ..., "error_code": ...}."""
    content: dict[str, Any] = {"detail": exc.detail, "error_code": exc.error_code}
    return JSONResponse(status_code=exc.status_code, content=content, headers=exc.headers)
