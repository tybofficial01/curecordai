"""
Auth service: OTP lifecycle, JWT issue/revoke, email+password, OAuth verification.
"""
import uuid
from datetime import datetime, timedelta, timezone

import httpx
import structlog
from fastapi import status
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token as google_id_token
from jose import JWTError, jwt
from sqlalchemy import func as sqlfunc
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.core.security import (
    JWT_ALGORITHM,
    create_access_token,
    create_refresh_token,
    generate_otp,
    generate_token,
    hash_otp,
    hash_password,
    hash_token,
    verify_otp,
    verify_password,
)
from app.core.enums import Language
from app.core.errors import ApiError, ErrorCode
from app.models.auth import User, UserOtpRequest, UserSession
from app.models.consent import ConsentRecord
from app.models.profile import UserProfile
from app.models.rbac import Role, UserRole
from app.models.settings import AppSetting
from app.services.email_templates import (
    OTP_PURPOSE_RESET_PASSWORD,
    OTP_PURPOSE_VERIFY_EMAIL,
)
from app.services.twilio_service import twilio_service

logger = structlog.get_logger()

_OTP_VERIFIED_TOKEN_EXPIRE_MINUTES = 10
_EMAIL_VERIFIED_TOKEN_EXPIRE_MINUTES = 10
_EMAIL_OTP_PURPOSE = "email_registration"
_PASSWORD_RESET_OTP_PURPOSE = "password_reset"

# Computed once at import - always run through bcrypt even when there's no real hash to check
# against, so "no such account" and "wrong password" take the same time (closes an account
# enumeration side-channel; see SECURITY_AUDIT.md M8).
_DUMMY_PASSWORD_HASH = hash_password("dummy-password-for-constant-time-compare")


async def _resolve_user_language(db: AsyncSession, user_id) -> Language:
    """The user's saved AppSetting.language, or English if unset/unrecognized.

    Auth flows are often pre-account (first-time signup has no user row, and therefore no
    AppSetting), so English is the honest default rather than a failure.
    """
    saved = await db.scalar(select(AppSetting.language).where(AppSetting.user_id == user_id))
    if not saved:
        return Language.EN
    try:
        return Language(saved)
    except ValueError:
        logger.warning("Unrecognized saved language - falling back to English", user_id=str(user_id))
        return Language.EN


async def send_otp(
    db: AsyncSession,
    phone_number: str,
    purpose: str,
    ip_address: str | None,
    user_agent: str | None,
) -> int:
    """Generate OTP, store bcrypt hash, dispatch SMS. Returns expiry seconds."""
    logger.debug("send_otp started", phone_number=phone_number, purpose=purpose)

    cutoff = datetime.now(timezone.utc) - timedelta(minutes=10)
    recent_count = await db.scalar(
        select(sqlfunc.count()).select_from(UserOtpRequest).where(
            UserOtpRequest.recipient == phone_number,
            UserOtpRequest.purpose == purpose,
            UserOtpRequest.created_at >= cutoff,
        )
    )
    if recent_count and recent_count >= 3:
        logger.warning(
            "OTP request throttled - too many requests in 10-minute window",
            phone_number=phone_number,
            purpose=purpose,
            recent_count=recent_count,
        )
        raise ApiError(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many OTP requests. Please wait 10 minutes.",
            error_code=ErrorCode.OTP_RATE_LIMITED,
        )

    otp = generate_otp()
    otp_hash = hash_otp(otp)
    expires_at = datetime.now(timezone.utc) + timedelta(minutes=settings.OTP_EXPIRE_MINUTES)

    existing_user = await db.scalar(
        select(User).where(User.phone_number == phone_number, User.is_deleted == False)  # noqa: E712
    )
    logger.debug(
        "OTP recipient lookup",
        phone_number=phone_number,
        existing_user=bool(existing_user),
        purpose=purpose,
    )

    otp_record = UserOtpRequest(
        user_id=existing_user.id if existing_user else None,
        channel="sms",
        recipient=phone_number,
        otp_hash=otp_hash,
        purpose=purpose,
        expires_at=expires_at,
        ip_address=ip_address,
        user_agent=user_agent,
    )
    db.add(otp_record)
    await db.commit()
    logger.debug("OTP request record persisted", phone_number=phone_number, expires_at=expires_at.isoformat())

    # OTP is often pre-auth (first-time signup, no user record yet) - only thread a real
    # language preference when an account (and therefore an AppSetting) already exists.
    otp_sms_language = (
        await _resolve_user_language(db, existing_user.id) if existing_user else Language.EN
    )

    await twilio_service.send_otp_sms(phone_number, otp, language=otp_sms_language)
    logger.info("OTP dispatched", phone_number=phone_number, purpose=purpose)
    return settings.OTP_EXPIRE_MINUTES * 60


async def verify_otp_and_issue_tokens(
    db: AsyncSession,
    phone_number: str,
    plain_otp: str,
    purpose: str,
    ip_address: str | None,
    user_agent: str | None,
    device_id: str | None = None,
    device_name: str | None = None,
) -> dict:
    """
    Validate OTP. Returns:
    - Existing users (login): full token dict with is_new_user=False
    - New phone numbers: is_new_user=True + otp_verified_token for /register step
    """
    logger.debug("verify_otp_and_issue_tokens started", phone_number=phone_number, purpose=purpose)
    now = datetime.now(timezone.utc)
    otp_record = await db.scalar(
        select(UserOtpRequest)
        .where(
            UserOtpRequest.recipient == phone_number,
            UserOtpRequest.purpose == purpose,
            UserOtpRequest.is_used == False,  # noqa: E712
            UserOtpRequest.expires_at > now,
        )
        .order_by(UserOtpRequest.created_at.desc())
        .limit(1)
    )

    if not otp_record:
        logger.warning("OTP verify failed - no active OTP found", phone_number=phone_number, purpose=purpose)
        raise ApiError(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="OTP expired or not found",
            error_code=ErrorCode.OTP_NOT_FOUND,
        )

    otp_record.attempt_count += 1
    if otp_record.attempt_count > otp_record.max_attempts:
        await db.commit()
        logger.warning(
            "OTP verify failed - attempt limit exceeded",
            phone_number=phone_number,
            attempt_count=otp_record.attempt_count,
            max_attempts=otp_record.max_attempts,
        )
        raise ApiError(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="OTP attempt limit exceeded",
            error_code=ErrorCode.OTP_ATTEMPTS_EXCEEDED,
        )

    if not verify_otp(plain_otp, otp_record.otp_hash):
        await db.commit()
        logger.warning(
            "OTP verify failed - code mismatch",
            phone_number=phone_number,
            attempt_count=otp_record.attempt_count,
        )
        raise ApiError(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid OTP",
            error_code=ErrorCode.OTP_INVALID,
        )

    otp_record.is_used = True
    otp_record.used_at = now
    logger.debug("OTP verified successfully", phone_number=phone_number, purpose=purpose)

    user = await db.scalar(
        select(User).where(User.phone_number == phone_number, User.is_deleted == False)  # noqa: E712
    )

    if user is None and purpose == "login":
        await db.commit()
        logger.info("OTP login attempted for unregistered phone number", phone_number=phone_number)
        raise ApiError(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Phone number not registered",
            error_code=ErrorCode.PHONE_NOT_REGISTERED,
        )

    if user is None:
        await db.commit()
        logger.info("OTP verified for new phone number - proceeding to registration", phone_number=phone_number)
        return {
            "verified": True,
            "is_new_user": True,
            "otp_verified_token": _issue_otp_verified_token(phone_number),
        }

    if purpose == "registration":
        await db.commit()
        logger.info("Registration OTP verified for already-registered phone - rejecting", phone_number=phone_number)
        raise ApiError(
            status_code=status.HTTP_409_CONFLICT,
            detail="Phone number already registered",
            error_code=ErrorCode.PHONE_ALREADY_REGISTERED,
        )

    user.is_phone_verified = True
    user.last_login_at = now
    await db.commit()
    logger.info("OTP login succeeded", user_id=str(user.id), phone_number=phone_number)

    return await _create_session_tokens(db, user, ip_address, user_agent, device_id, device_name)


def _write_registration_consents(db, user_id, ip_address: str | None, user_agent: str | None) -> None:
    """Record implicit consent for ToS + Privacy Policy accepted at registration."""
    for consent_type in ("terms_of_service", "privacy_policy", "data_processing"):
        db.add(ConsentRecord(
            user_id=user_id,
            consent_type=consent_type,
            policy_version="1.0",
            is_granted=True,
            ip_address=ip_address,
            user_agent=user_agent,
            jurisdiction="PK",
        ))


def _issue_otp_verified_token(phone_number: str) -> str:
    expires_at = datetime.now(timezone.utc) + timedelta(minutes=_OTP_VERIFIED_TOKEN_EXPIRE_MINUTES)
    payload = {"sub": phone_number, "type": "otp_verified", "exp": expires_at}
    return jwt.encode(payload, settings.jwt_private_key, algorithm=JWT_ALGORITHM)


def _decode_otp_verified_token(token: str) -> str:
    try:
        payload = jwt.decode(token, settings.jwt_public_key, algorithms=[JWT_ALGORITHM])
        if payload.get("type") != "otp_verified":
            raise JWTError("Not an otp_verified token")
        return payload["sub"]
    except (JWTError, KeyError) as exc:
        raise ValueError("Invalid or expired OTP verification token") from exc


def _issue_email_verified_token(email: str) -> str:
    expires_at = datetime.now(timezone.utc) + timedelta(minutes=_EMAIL_VERIFIED_TOKEN_EXPIRE_MINUTES)
    payload = {"sub": email, "type": "email_verified", "exp": expires_at}
    return jwt.encode(payload, settings.jwt_private_key, algorithm=JWT_ALGORITHM)


def _decode_email_verified_token(token: str) -> str:
    try:
        payload = jwt.decode(token, settings.jwt_public_key, algorithms=[JWT_ALGORITHM])
        if payload.get("type") != "email_verified":
            raise JWTError("Not an email_verified token")
        return payload["sub"]
    except (JWTError, KeyError) as exc:
        raise ValueError("Invalid or expired email verification token") from exc


async def send_email_otp(
    db: AsyncSession,
    email: str,
    ip_address: str | None,
    user_agent: str | None,
) -> int:
    """Generate OTP, store bcrypt hash, dispatch email. Returns expiry seconds."""
    email = email.lower()
    logger.debug("send_email_otp started", email=email)

    existing_user = await db.scalar(
        select(User).where(User.email == email, User.is_deleted == False)  # noqa: E712
    )
    if existing_user:
        logger.info("Email OTP rejected - already registered", email=email)
        raise ApiError(
            status_code=status.HTTP_409_CONFLICT,
            detail="Email already registered",
            error_code=ErrorCode.EMAIL_ALREADY_REGISTERED,
        )

    cutoff = datetime.now(timezone.utc) - timedelta(minutes=10)
    recent_count = await db.scalar(
        select(sqlfunc.count()).select_from(UserOtpRequest).where(
            UserOtpRequest.recipient == email,
            UserOtpRequest.purpose == _EMAIL_OTP_PURPOSE,
            UserOtpRequest.created_at >= cutoff,
        )
    )
    if recent_count and recent_count >= 3:
        logger.warning(
            "Email OTP request throttled - too many requests in 10-minute window",
            email=email,
            recent_count=recent_count,
        )
        raise ApiError(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many OTP requests. Please wait 10 minutes.",
            error_code=ErrorCode.OTP_RATE_LIMITED,
        )

    otp = generate_otp()
    otp_hash = hash_otp(otp)
    expires_at = datetime.now(timezone.utc) + timedelta(minutes=settings.OTP_EXPIRE_MINUTES)

    db.add(UserOtpRequest(
        user_id=None,
        channel="email",
        recipient=email,
        otp_hash=otp_hash,
        purpose=_EMAIL_OTP_PURPOSE,
        expires_at=expires_at,
        ip_address=ip_address,
        user_agent=user_agent,
    ))
    await db.commit()
    logger.debug("Email OTP request record persisted", email=email, expires_at=expires_at.isoformat())

    # Registration-email OTP is by definition pre-account (the guard above rejects an
    # already-registered address), so there is no saved AppSetting to read - English.
    sent = await twilio_service.send_otp_email(
        email, otp, purpose=OTP_PURPOSE_VERIFY_EMAIL, language=Language.EN
    )
    if not sent:
        logger.error("Email OTP send failed - SMTP dispatch unsuccessful", email=email)
        raise ApiError(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Could not send verification email. Please try again shortly.",
            error_code=ErrorCode.OTP_DELIVERY_FAILED,
        )
    logger.info("Email OTP dispatched", email=email)
    return settings.OTP_EXPIRE_MINUTES * 60


async def verify_email_otp(
    db: AsyncSession,
    email: str,
    plain_otp: str,
    ip_address: str | None,
    user_agent: str | None,
) -> str:
    """Validate email OTP. Returns a short-lived email_verified_token for /auth/register/email."""
    email = email.lower()
    logger.debug("verify_email_otp started", email=email)
    now = datetime.now(timezone.utc)
    otp_record = await db.scalar(
        select(UserOtpRequest)
        .where(
            UserOtpRequest.recipient == email,
            UserOtpRequest.purpose == _EMAIL_OTP_PURPOSE,
            UserOtpRequest.is_used == False,  # noqa: E712
            UserOtpRequest.expires_at > now,
        )
        .order_by(UserOtpRequest.created_at.desc())
        .limit(1)
    )

    if not otp_record:
        logger.warning("Email OTP verify failed - no active OTP found", email=email)
        raise ApiError(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="OTP expired or not found",
            error_code=ErrorCode.OTP_NOT_FOUND,
        )

    otp_record.attempt_count += 1
    if otp_record.attempt_count > otp_record.max_attempts:
        await db.commit()
        logger.warning(
            "Email OTP verify failed - attempt limit exceeded",
            email=email,
            attempt_count=otp_record.attempt_count,
            max_attempts=otp_record.max_attempts,
        )
        raise ApiError(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="OTP attempt limit exceeded",
            error_code=ErrorCode.OTP_ATTEMPTS_EXCEEDED,
        )

    if not verify_otp(plain_otp, otp_record.otp_hash):
        await db.commit()
        logger.warning(
            "Email OTP verify failed - code mismatch",
            email=email,
            attempt_count=otp_record.attempt_count,
        )
        raise ApiError(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid OTP",
            error_code=ErrorCode.OTP_INVALID,
        )

    otp_record.is_used = True
    otp_record.used_at = now
    await db.commit()
    logger.info("Email OTP verified successfully", email=email)

    return _issue_email_verified_token(email)


async def send_password_reset_otp(
    db: AsyncSession,
    email: str,
    ip_address: str | None,
    user_agent: str | None,
) -> int:
    """
    Generate + email a password reset OTP for email/password accounts.
    Always returns the same expiry regardless of whether the account exists,
    so callers can't use this endpoint to enumerate registered emails.
    """
    email = email.lower()
    logger.debug("send_password_reset_otp started", email=email)

    cutoff = datetime.now(timezone.utc) - timedelta(minutes=10)
    recent_count = await db.scalar(
        select(sqlfunc.count()).select_from(UserOtpRequest).where(
            UserOtpRequest.recipient == email,
            UserOtpRequest.purpose == _PASSWORD_RESET_OTP_PURPOSE,
            UserOtpRequest.created_at >= cutoff,
        )
    )
    if recent_count and recent_count >= 3:
        logger.warning(
            "Password reset OTP throttled - too many requests in 10-minute window",
            email=email,
            recent_count=recent_count,
        )
        raise ApiError(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many requests. Please wait 10 minutes.",
            error_code=ErrorCode.OTP_RATE_LIMITED,
        )

    user = await db.scalar(
        select(User).where(User.email == email, User.is_deleted == False)  # noqa: E712
    )

    # Only email/password accounts have a password to reset. Silently skip
    # sending for anyone else (unregistered email, OAuth-only account) -
    # the response is identical either way.
    if user and user.password_hash:
        otp = generate_otp()
        otp_hash = hash_otp(otp)
        expires_at = datetime.now(timezone.utc) + timedelta(minutes=settings.OTP_EXPIRE_MINUTES)
        db.add(UserOtpRequest(
            user_id=user.id,
            channel="email",
            recipient=email,
            otp_hash=otp_hash,
            purpose=_PASSWORD_RESET_OTP_PURPOSE,
            expires_at=expires_at,
            ip_address=ip_address,
            user_agent=user_agent,
        ))
        await db.commit()
        await twilio_service.send_otp_email(
            email,
            otp,
            purpose=OTP_PURPOSE_RESET_PASSWORD,
            language=await _resolve_user_language(db, user.id),
        )
        logger.info("Password reset OTP dispatched", email=email)
    else:
        logger.info("Password reset requested for non-resettable email - no OTP sent", email=email)

    return settings.OTP_EXPIRE_MINUTES * 60


async def reset_password_with_otp(
    db: AsyncSession,
    email: str,
    plain_otp: str,
    new_password: str,
    ip_address: str | None,
    user_agent: str | None,
) -> dict:
    """Validate the password reset OTP, set the new password, and sign the user in."""
    email = email.lower()
    logger.debug("reset_password_with_otp started", email=email)
    now = datetime.now(timezone.utc)
    otp_record = await db.scalar(
        select(UserOtpRequest)
        .where(
            UserOtpRequest.recipient == email,
            UserOtpRequest.purpose == _PASSWORD_RESET_OTP_PURPOSE,
            UserOtpRequest.is_used == False,  # noqa: E712
            UserOtpRequest.expires_at > now,
        )
        .order_by(UserOtpRequest.created_at.desc())
        .limit(1)
    )

    if not otp_record:
        logger.warning("Password reset failed - no active OTP found", email=email)
        raise ApiError(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Code expired or not found",
            error_code=ErrorCode.OTP_NOT_FOUND,
        )

    otp_record.attempt_count += 1
    if otp_record.attempt_count > otp_record.max_attempts:
        await db.commit()
        logger.warning(
            "Password reset failed - attempt limit exceeded",
            email=email,
            attempt_count=otp_record.attempt_count,
        )
        raise ApiError(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Code attempt limit exceeded",
            error_code=ErrorCode.OTP_ATTEMPTS_EXCEEDED,
        )

    if not verify_otp(plain_otp, otp_record.otp_hash):
        await db.commit()
        logger.warning("Password reset failed - code mismatch", email=email, attempt_count=otp_record.attempt_count)
        raise ApiError(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid code",
            error_code=ErrorCode.OTP_INVALID,
        )

    user = await db.scalar(
        select(User).where(User.email == email, User.is_deleted == False)  # noqa: E712
    )
    if not user or not user.password_hash:
        await db.commit()
        logger.warning("Password reset failed - no resettable account for email", email=email)
        raise ApiError(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid code",
            error_code=ErrorCode.OTP_INVALID,
        )

    otp_record.is_used = True
    otp_record.used_at = now
    user.password_hash = hash_password(new_password)

    # Resetting a password is a credible sign of account compromise risk -
    # revoke every other active session so a stolen session can't outlive the reset.
    await db.execute(
        update(UserSession)
        .where(UserSession.user_id == user.id, UserSession.is_active == True)  # noqa: E712
        .values(is_active=False, revoked_at=now, revoke_reason="password_reset")
    )
    await db.commit()
    logger.info("Password reset succeeded", user_id=str(user.id))

    return await _create_session_tokens(db, user, ip_address, user_agent)


async def register_with_phone(
    db: AsyncSession,
    otp_verified_token: str,
    full_name: str,
    ip_address: str | None,
    user_agent: str | None,
) -> dict:
    try:
        phone_number = _decode_otp_verified_token(otp_verified_token)
    except ValueError as exc:
        logger.warning("Phone registration failed - invalid otp_verified_token", error=str(exc))
        raise ApiError(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired OTP verification token",
            error_code=ErrorCode.OTP_TOKEN_INVALID,
        )

    existing = await db.scalar(
        select(User).where(User.phone_number == phone_number, User.is_deleted == False)  # noqa: E712
    )
    if existing:
        logger.info("Phone registration rejected - already registered", phone_number=phone_number)
        raise ApiError(
            status_code=status.HTTP_409_CONFLICT,
            detail="Phone number already registered",
            error_code=ErrorCode.PHONE_ALREADY_REGISTERED,
        )

    user = User(
        phone_number=phone_number,
        auth_provider="phone",
        is_active=True,
        is_phone_verified=True,
        data_region="PK",
    )
    db.add(user)
    await db.flush()

    db.add(UserProfile(
        user_id=user.id,
        full_name=full_name,
        patient_id_display=await _generate_patient_display_id(db),
        profile_completion_pct=20,
    ))
    await _assign_default_role(db, user.id)
    _write_registration_consents(db, user.id, ip_address, user_agent)
    user.last_login_at = datetime.now(timezone.utc)
    await db.commit()
    logger.info("Phone registration completed", user_id=str(user.id), phone_number=phone_number)

    return await _create_session_tokens(db, user, ip_address, user_agent)


async def login_email_password(
    db: AsyncSession,
    email: str,
    password: str,
    ip_address: str | None,
    user_agent: str | None,
    device_id: str | None = None,
    device_name: str | None = None,
) -> dict:
    logger.debug("login_email_password started", email=email)
    now = datetime.now(timezone.utc)
    user = await db.scalar(
        select(User).where(User.email == email.lower(), User.is_deleted == False)  # noqa: E712
    )

    if user and user.locked_until and user.locked_until.replace(tzinfo=timezone.utc) > now:
        logger.info("Email login rejected - account temporarily locked", user_id=str(user.id))
        raise ApiError(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account temporarily locked due to repeated failed login attempts. Try again later.",
            error_code=ErrorCode.ACCOUNT_LOCKED,
        )

    # Always pay the bcrypt cost, even for a nonexistent account or one with no password
    # (OAuth-only) - a real vs. dummy hash check must take the same time either way.
    hash_to_check = user.password_hash if (user and user.password_hash) else _DUMMY_PASSWORD_HASH
    password_matches = verify_password(password, hash_to_check)

    if not user or not user.password_hash or not password_matches:
        if user:
            user.failed_login_attempts += 1
            if user.failed_login_attempts >= settings.LOGIN_LOCKOUT_MAX_ATTEMPTS:
                user.locked_until = now + timedelta(minutes=settings.LOGIN_LOCKOUT_MINUTES)
                logger.warning(
                    "Account locked - failed login attempt limit exceeded",
                    user_id=str(user.id),
                    failed_attempts=user.failed_login_attempts,
                )
            await db.commit()
        logger.info("Email login failed - invalid credentials", email=email)
        raise ApiError(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials",
            error_code=ErrorCode.INVALID_CREDENTIALS,
        )

    if not user.is_active:
        logger.info("Email login rejected - account deactivated", user_id=str(user.id))
        raise ApiError(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account deactivated",
            error_code=ErrorCode.ACCOUNT_DEACTIVATED,
        )

    user.failed_login_attempts = 0
    user.locked_until = None
    user.last_login_at = now
    await db.commit()
    logger.info("Email login succeeded", user_id=str(user.id))

    return await _create_session_tokens(db, user, ip_address, user_agent, device_id, device_name)


async def register_email_password(
    db: AsyncSession,
    email: str,
    password: str,
    full_name: str,
    email_verified_token: str,
    ip_address: str | None,
    user_agent: str | None,
) -> dict:
    email = email.lower()

    try:
        verified_email = _decode_email_verified_token(email_verified_token)
    except ValueError as exc:
        logger.warning("Email registration failed - invalid email_verified_token", error=str(exc))
        raise ApiError(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired email verification token",
            error_code=ErrorCode.EMAIL_TOKEN_INVALID,
        )

    if verified_email != email:
        logger.warning(
            "Email registration failed - token email mismatch",
            token_email=verified_email,
            body_email=email,
        )
        raise ApiError(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email verification token does not match this email address",
            error_code=ErrorCode.EMAIL_TOKEN_MISMATCH,
        )

    existing = await db.scalar(
        select(User).where(User.email == email, User.is_deleted == False)  # noqa: E712
    )
    if existing:
        logger.info("Email registration rejected - already registered", email=email)
        raise ApiError(
            status_code=status.HTTP_409_CONFLICT,
            detail="Email already registered",
            error_code=ErrorCode.EMAIL_ALREADY_REGISTERED,
        )

    user = User(
        email=email,
        password_hash=hash_password(password),
        auth_provider="email",
        is_active=True,
        is_email_verified=True,
        data_region="PK",
    )
    db.add(user)
    await db.flush()

    db.add(UserProfile(
        user_id=user.id,
        full_name=full_name,
        patient_id_display=await _generate_patient_display_id(db),
        profile_completion_pct=20,
    ))
    await _assign_default_role(db, user.id)
    _write_registration_consents(db, user.id, ip_address, user_agent)
    user.last_login_at = datetime.now(timezone.utc)
    await db.commit()
    logger.info("Email registration completed", user_id=str(user.id), email=email)

    return await _create_session_tokens(db, user, ip_address, user_agent)


async def login_google_oauth(
    db: AsyncSession,
    id_token_str: str,
    ip_address: str | None,
    user_agent: str | None,
) -> dict:
    try:
        id_info = google_id_token.verify_oauth2_token(
            id_token_str,
            google_requests.Request(),
            settings.GOOGLE_CLIENT_ID,
        )
    except Exception as exc:
        logger.warning("Google OAuth token verification failed", error=str(exc))
        raise ApiError(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Google token",
            error_code=ErrorCode.OAUTH_TOKEN_INVALID,
        )

    google_sub = id_info["sub"]
    email = id_info.get("email", "").lower()
    email_verified = bool(id_info.get("email_verified"))
    full_name = id_info.get("name", "")
    logger.debug("Google OAuth token verified", email=email, email_verified=email_verified)

    user = await db.scalar(
        select(User).where(
            User.oauth_provider_id == google_sub,
            User.auth_provider == "google",
            User.is_deleted == False,  # noqa: E712
        )
    )
    # Only trust the email for account linking if Google has verified it -
    # otherwise an attacker could take over an existing email/password account.
    if not user and email and email_verified:
        user = await db.scalar(
            select(User).where(User.email == email, User.is_deleted == False)  # noqa: E712
        )

    is_new_user = user is None
    if not user:
        logger.info("Google OAuth - creating new user", email=email)
        user = User(
            email=email if email_verified else None,
            auth_provider="google",
            oauth_provider_id=google_sub,
            is_active=True,
            is_email_verified=email_verified,
            data_region="PK",
        )
        db.add(user)
        await db.flush()
        db.add(UserProfile(
            user_id=user.id,
            full_name=full_name,
            patient_id_display=await _generate_patient_display_id(db),
            profile_completion_pct=20,
        ))
        await _assign_default_role(db, user.id)
        _write_registration_consents(db, user.id, ip_address, user_agent)
    else:
        user.oauth_provider_id = google_sub

    user.last_login_at = datetime.now(timezone.utc)
    await db.commit()
    logger.info("Google OAuth login succeeded", user_id=str(user.id))

    return await _create_session_tokens(db, user, ip_address, user_agent, is_new_user=is_new_user)


_APPLE_JWKS_TTL = timedelta(hours=24)  # Apple rotates these keys infrequently
_apple_jwks_cache: dict | None = None
_apple_jwks_cached_at: datetime | None = None


async def _get_apple_jwks() -> dict:
    """Cached fetch - avoids an external round trip on every single Apple sign-in."""
    global _apple_jwks_cache, _apple_jwks_cached_at
    now = datetime.now(timezone.utc)
    if (
        _apple_jwks_cache is None
        or _apple_jwks_cached_at is None
        or now - _apple_jwks_cached_at > _APPLE_JWKS_TTL
    ):
        async with httpx.AsyncClient() as client:
            keys_resp = await client.get("https://appleid.apple.com/auth/keys")
            keys_resp.raise_for_status()
            _apple_jwks_cache = keys_resp.json()
        _apple_jwks_cached_at = now
    return _apple_jwks_cache


async def login_apple_sign_in(
    db: AsyncSession,
    identity_token: str,
    full_name: str | None,
    ip_address: str | None,
    user_agent: str | None,
) -> dict:
    try:
        apple_keys = await _get_apple_jwks()

        unverified_header = jwt.get_unverified_header(identity_token)
        kid = unverified_header.get("kid")
        apple_key = next(
            (k for k in apple_keys.get("keys", []) if k.get("kid") == kid),
            None,
        )
        if not apple_key:
            raise ValueError("Apple public key not found")

        import base64
        from cryptography.hazmat.backends import default_backend
        from cryptography.hazmat.primitives.asymmetric.rsa import RSAPublicNumbers

        def _b64_to_int(val: str) -> int:
            padded = val + "=" * (4 - len(val) % 4)
            return int.from_bytes(base64.urlsafe_b64decode(padded), byteorder="big")

        public_key = RSAPublicNumbers(
            _b64_to_int(apple_key["e"]),
            _b64_to_int(apple_key["n"]),
        ).public_key(default_backend())

        payload = jwt.decode(
            identity_token,
            public_key,
            algorithms=["RS256"],
            audience=settings.APPLE_CLIENT_ID,
            issuer="https://appleid.apple.com",
        )
    except Exception as exc:
        logger.warning("Apple Sign In token verification failed", error=str(exc))
        raise ApiError(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Apple token",
            error_code=ErrorCode.OAUTH_TOKEN_INVALID,
        )

    apple_sub = payload["sub"]
    email = payload.get("email", "").lower() or None
    email_verified = str(payload.get("email_verified", "")).lower() == "true"
    logger.debug("Apple Sign In token verified", email=email, email_verified=email_verified)

    user = await db.scalar(
        select(User).where(
            User.oauth_provider_id == apple_sub,
            User.auth_provider == "apple",
            User.is_deleted == False,  # noqa: E712
        )
    )
    # Only trust the email for account linking if Apple has verified it -
    # otherwise an attacker could take over an existing email/password account.
    if not user and email and email_verified:
        user = await db.scalar(
            select(User).where(User.email == email, User.is_deleted == False)  # noqa: E712
        )
        if user:
            user.oauth_provider_id = apple_sub

    is_new_user = user is None
    if not user:
        # Unverified email must not be attached - it may already belong to
        # another account and would trip the unique constraint on users.email.
        safe_email = email if email_verified else None

        logger.info("Apple Sign In - creating new user", email=safe_email)
        user = User(
            email=safe_email,
            auth_provider="apple",
            oauth_provider_id=apple_sub,
            is_active=True,
            is_email_verified=email_verified,
            data_region="PK",
        )
        db.add(user)
        await db.flush()
        db.add(UserProfile(
            user_id=user.id,
            full_name=full_name or "Apple User",
            patient_id_display=await _generate_patient_display_id(db),
            profile_completion_pct=20,
        ))
        await _assign_default_role(db, user.id)
        _write_registration_consents(db, user.id, ip_address, user_agent)

    user.last_login_at = datetime.now(timezone.utc)
    await db.commit()
    logger.info("Apple Sign In login succeeded", user_id=str(user.id))

    return await _create_session_tokens(db, user, ip_address, user_agent, is_new_user=is_new_user)


async def refresh_tokens(
    db: AsyncSession,
    refresh_token: str,
    ip_address: str | None,
    user_agent: str | None,
) -> dict:
    from app.core.security import decode_refresh_token

    try:
        payload = decode_refresh_token(refresh_token)
    except ValueError:
        logger.info("Token refresh rejected - invalid refresh token")
        raise ApiError(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token",
            error_code=ErrorCode.REFRESH_TOKEN_INVALID,
        )

    user_id = uuid.UUID(payload["sub"])
    token_hash = hash_token(refresh_token)

    # Look up regardless of is_active first - an inactive match whose is_active=False came
    # from token_rotation (not logout/expiry) means this refresh token was already rotated
    # once and is being replayed, a credible signal of token theft.
    session = await db.scalar(
        select(UserSession).where(
            UserSession.refresh_token_hash == token_hash,
            UserSession.user_id == user_id,
        )
    )
    if not session:
        logger.info("Token refresh rejected - session revoked or not found", user_id=str(user_id))
        raise ApiError(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token revoked or not found",
            error_code=ErrorCode.REFRESH_TOKEN_INVALID,
        )

    if not session.is_active:
        if session.revoke_reason == "token_rotation":
            from app.models.security import SecurityIncident

            now = datetime.now(timezone.utc)
            await db.execute(
                update(UserSession)
                .where(UserSession.user_id == user_id, UserSession.is_active == True)  # noqa: E712
                .values(is_active=False, revoked_at=now, revoke_reason="token_replay_detected")
            )
            db.add(SecurityIncident(
                incident_type="refresh_token_replay",
                severity="high",
                status="open",
                description=f"Refresh token reused after rotation for user {user_id} - all sessions revoked.",
                affected_user_id=user_id,
                discovered_at=now,
            ))
            await db.commit()
            logger.warning("Refresh token replay detected - all sessions revoked", user_id=str(user_id))
        raise ApiError(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token revoked or not found",
            error_code=ErrorCode.REFRESH_TOKEN_INVALID,
        )

    if session.expires_at.replace(tzinfo=timezone.utc) < datetime.now(timezone.utc):
        session.is_active = False
        await db.commit()
        logger.info("Token refresh rejected - refresh token expired", user_id=str(user_id))
        raise ApiError(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token expired",
            error_code=ErrorCode.REFRESH_TOKEN_EXPIRED,
        )

    user = await db.get(User, user_id)
    if not user or not user.is_active or user.is_deleted:
        logger.info("Token refresh rejected - user not found or deactivated", user_id=str(user_id))
        raise ApiError(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found or deactivated",
            error_code=ErrorCode.SESSION_USER_UNAVAILABLE,
        )

    session.is_active = False
    session.revoked_at = datetime.now(timezone.utc)
    session.revoke_reason = "token_rotation"
    await db.flush()
    logger.info("Token refresh succeeded - old session rotated", user_id=str(user_id), old_session_id=str(session.id))

    return await _create_session_tokens(db, user, ip_address, user_agent)


async def logout(
    db: AsyncSession,
    current_user: User,
    access_token: str,
    refresh_token: str | None,
    all_devices: bool,
) -> None:
    if all_devices:
        await db.execute(
            update(UserSession)
            .where(UserSession.user_id == current_user.id, UserSession.is_active == True)  # noqa: E712
            .values(
                is_active=False,
                revoked_at=datetime.now(timezone.utc),
                revoke_reason="logout_all_devices",
            )
        )
        logger.info("Logout - all devices revoked", user_id=str(current_user.id))
    else:
        token_hash = hash_token(access_token)
        session = await db.scalar(
            select(UserSession).where(
                UserSession.session_token_hash == token_hash,
                UserSession.is_active == True,  # noqa: E712
            )
        )
        if session:
            session.is_active = False
            session.revoked_at = datetime.now(timezone.utc)
            session.revoke_reason = "logout"
            logger.info("Logout - session revoked", user_id=str(current_user.id), session_id=str(session.id))
        else:
            logger.debug("Logout requested - no matching active session found", user_id=str(current_user.id))

    await db.commit()


# ── Internal helpers ───────────────────────────────────────────────────────────

async def _create_session_tokens(
    db: AsyncSession,
    user: User,
    ip_address: str | None,
    user_agent: str | None,
    device_id: str | None = None,
    device_name: str | None = None,
    is_new_user: bool = False,
) -> dict:
    role_name = await _get_primary_role(db, user.id)

    access_token, access_expires = create_access_token(user.id, role_name)
    refresh_token, refresh_expires = create_refresh_token(user.id)

    db.add(UserSession(
        user_id=user.id,
        session_token_hash=hash_token(access_token),
        refresh_token_hash=hash_token(refresh_token),
        device_id=device_id,
        device_name=device_name,
        device_type=_parse_device_type(user_agent or ""),
        ip_address=ip_address,
        user_agent=user_agent,
        is_active=True,
        expires_at=refresh_expires,
        last_activity_at=datetime.now(timezone.utc),
    ))
    await db.commit()
    logger.debug(
        "Session tokens created",
        user_id=str(user.id),
        role=role_name,
        device_type=_parse_device_type(user_agent or ""),
        access_expires_at=access_expires.isoformat(),
    )

    return {
        "user": user,
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "expires_at": access_expires,
        "is_new_user": is_new_user,
    }


async def _get_primary_role(db: AsyncSession, user_id: uuid.UUID) -> str:
    role = await db.scalar(
        select(Role.name)
        .join(UserRole, UserRole.role_id == Role.id)
        .where(UserRole.user_id == user_id, UserRole.is_active == True)  # noqa: E712
        .order_by(UserRole.created_at.asc())
        .limit(1)
    )
    return role or "patient"


async def _assign_default_role(db: AsyncSession, user_id: uuid.UUID) -> None:
    patient_role = await db.scalar(select(Role).where(Role.name == "patient"))
    if patient_role:
        db.add(UserRole(user_id=user_id, role_id=patient_role.id, is_active=True))


async def _generate_patient_display_id(db: AsyncSession) -> str:
    import random
    import string
    while True:
        letters = "".join(random.choices(string.ascii_uppercase, k=2))
        digits = "".join(random.choices(string.digits, k=5))
        candidate = f"#{letters}-{digits}"
        if not await db.scalar(select(UserProfile).where(UserProfile.patient_id_display == candidate)):
            return candidate


def _parse_device_type(user_agent: str) -> str:
    ua = user_agent.lower()
    if "android" in ua:
        return "android"
    if "iphone" in ua or "ipad" in ua or "ios" in ua:
        return "ios"
    if "mozilla" in ua or "chrome" in ua or "safari" in ua:
        return "web"
    return "api"
