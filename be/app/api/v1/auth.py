import structlog
from fastapi import APIRouter, HTTPException, Request, status

from app.config import settings
from app.core.rate_limit import limiter
from app.dependencies import CurrentUser, DB
from app.schemas.auth import (
    AppleSignInRequest,
    AuthResponse,
    AuthUserOut,
    EmailLoginRequest,
    EmailOtpSendRequest,
    EmailOtpVerifyRequest,
    EmailOtpVerifyResponse,
    EmailRegisterRequest,
    GoogleOAuthRequest,
    LogoutRequest,
    OtpSendRequest,
    OtpSendResponse,
    OtpVerifyRequest,
    OtpVerifyResponse,
    PasswordResetConfirmRequest,
    PasswordResetRequestRequest,
    RegisterRequest,
    TokenRefreshRequest,
    TokenResponse,
)
from app.services import auth_service

logger = structlog.get_logger()

router = APIRouter(prefix="/auth", tags=["auth"])


def _client_ip(request: Request) -> str | None:
    raw_ip = request.client.host if request.client else None
    # Only honor X-Forwarded-For from a configured trusted proxy - otherwise any caller
    # can forge it, and this value is persisted into OTP/session audit trails. Empty
    # TRUSTED_PROXY_IPS (the default with no reverse proxy deployed) always uses raw_ip.
    if raw_ip and raw_ip in settings.trusted_proxy_ips_list:
        forwarded = request.headers.get("x-forwarded-for")
        if forwarded:
            return forwarded.split(",")[0].strip()
    return raw_ip


# ── OTP ───────────────────────────────────────────────────────────────────────

@router.post(
    "/otp/send",
    response_model=OtpSendResponse,
    summary="Request OTP via SMS",
)
@limiter.limit("5/minute")
async def send_otp(request: Request, body: OtpSendRequest, db: DB):
    logger.debug("POST /auth/otp/send", purpose=body.purpose)
    expires_in = await auth_service.send_otp(
        db=db,
        phone_number=body.phone_number,
        purpose=body.purpose,
        ip_address=_client_ip(request),
        user_agent=request.headers.get("user-agent"),
    )
    return OtpSendResponse(
        message="OTP sent successfully",
        expires_in_seconds=expires_in,
    )


@router.post(
    "/otp/verify",
    response_model=OtpVerifyResponse,
    summary="Verify OTP - returns tokens for existing users, otp_verified_token for new users",
)
@limiter.limit("10/minute")
async def verify_otp(request: Request, body: OtpVerifyRequest, db: DB):
    result = await auth_service.verify_otp_and_issue_tokens(
        db=db,
        phone_number=body.phone_number,
        plain_otp=body.otp,
        purpose=body.purpose,
        ip_address=_client_ip(request),
        user_agent=request.headers.get("user-agent"),
    )

    if result.get("is_new_user"):
        return OtpVerifyResponse(
            verified=True,
            is_new_user=True,
            otp_verified_token=result.get("otp_verified_token"),
        )

    return OtpVerifyResponse(
        verified=True,
        is_new_user=False,
        access_token=result["access_token"],
        refresh_token=result["refresh_token"],
        expires_at=result["expires_at"],
    )


# ── Phone Registration (after OTP verify) ─────────────────────────────────────

@router.post(
    "/register",
    response_model=AuthResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Complete phone registration after OTP verification",
)
@limiter.limit("10/minute")
async def register_phone(request: Request, body: RegisterRequest, db: DB):
    result = await auth_service.register_with_phone(
        db=db,
        otp_verified_token=body.otp_verified_token,
        full_name=body.full_name,
        ip_address=_client_ip(request),
        user_agent=request.headers.get("user-agent"),
    )  # phone_number is embedded in otp_verified_token (decoded server-side)
    return AuthResponse(
        user=AuthUserOut.model_validate(result["user"]),
        access_token=result["access_token"],
        refresh_token=result["refresh_token"],
        expires_at=result["expires_at"],
        is_new_user=result["is_new_user"],
    )


# ── Email OTP (verify email ownership before password registration) ──────────

@router.post(
    "/otp/send-email",
    response_model=OtpSendResponse,
    summary="Send OTP to email to verify ownership before password registration",
)
@limiter.limit("5/minute")
async def send_email_otp(request: Request, body: EmailOtpSendRequest, db: DB):
    expires_in = await auth_service.send_email_otp(
        db=db,
        email=body.email,
        ip_address=_client_ip(request),
        user_agent=request.headers.get("user-agent"),
    )
    return OtpSendResponse(
        message="OTP sent successfully",
        expires_in_seconds=expires_in,
    )


@router.post(
    "/otp/verify-email",
    response_model=EmailOtpVerifyResponse,
    summary="Verify email OTP - returns email_verified_token for /auth/register/email",
)
@limiter.limit("10/minute")
async def verify_email_otp(request: Request, body: EmailOtpVerifyRequest, db: DB):
    email_verified_token = await auth_service.verify_email_otp(
        db=db,
        email=body.email,
        plain_otp=body.otp,
        ip_address=_client_ip(request),
        user_agent=request.headers.get("user-agent"),
    )
    return EmailOtpVerifyResponse(verified=True, email_verified_token=email_verified_token)


# ── Email + Password ───────────────────────────────────────────────────────────

@router.post(
    "/register/email",
    response_model=AuthResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Register with email and password (requires email_verified_token from /auth/otp/verify-email)",
)
@limiter.limit("10/minute")
async def register_email(request: Request, body: EmailRegisterRequest, db: DB):
    result = await auth_service.register_email_password(
        db=db,
        email=body.email,
        password=body.password,
        full_name=body.full_name,
        email_verified_token=body.email_verified_token,
        ip_address=_client_ip(request),
        user_agent=request.headers.get("user-agent"),
    )
    return AuthResponse(
        user=AuthUserOut.model_validate(result["user"]),
        access_token=result["access_token"],
        refresh_token=result["refresh_token"],
        expires_at=result["expires_at"],
        is_new_user=result["is_new_user"],
    )


@router.post(
    "/login/email",
    response_model=AuthResponse,
    summary="Login with email and password",
)
@limiter.limit("10/minute")
async def login_email(request: Request, body: EmailLoginRequest, db: DB):
    result = await auth_service.login_email_password(
        db=db,
        email=body.email,
        password=body.password,
        ip_address=_client_ip(request),
        user_agent=request.headers.get("user-agent"),
        device_id=body.device_id,
        device_name=body.device_name,
    )
    return AuthResponse(
        user=AuthUserOut.model_validate(result["user"]),
        access_token=result["access_token"],
        refresh_token=result["refresh_token"],
        expires_at=result["expires_at"],
        is_new_user=result["is_new_user"],
    )


# ── Password reset ──────────────────────────────────────────────────────────

@router.post(
    "/password/forgot",
    response_model=OtpSendResponse,
    summary="Request a password reset code via email",
)
@limiter.limit("5/minute")
async def forgot_password(request: Request, body: PasswordResetRequestRequest, db: DB):
    expires_in = await auth_service.send_password_reset_otp(
        db=db,
        email=body.email,
        ip_address=_client_ip(request),
        user_agent=request.headers.get("user-agent"),
    )
    return OtpSendResponse(
        message="If that email is registered, we've sent a password reset code.",
        expires_in_seconds=expires_in,
    )


@router.post(
    "/password/reset",
    response_model=AuthResponse,
    summary="Reset password using the emailed code - signs the user in on success",
)
@limiter.limit("10/minute")
async def reset_password(request: Request, body: PasswordResetConfirmRequest, db: DB):
    result = await auth_service.reset_password_with_otp(
        db=db,
        email=body.email,
        plain_otp=body.otp,
        new_password=body.new_password,
        ip_address=_client_ip(request),
        user_agent=request.headers.get("user-agent"),
    )
    return AuthResponse(
        user=AuthUserOut.model_validate(result["user"]),
        access_token=result["access_token"],
        refresh_token=result["refresh_token"],
        expires_at=result["expires_at"],
        is_new_user=result["is_new_user"],
    )


# ── OAuth ─────────────────────────────────────────────────────────────────────

@router.post(
    "/oauth/google",
    response_model=AuthResponse,
    summary="Sign in with Google (ID token from client)",
)
@limiter.limit("20/minute")
async def google_oauth(request: Request, body: GoogleOAuthRequest, db: DB):
    result = await auth_service.login_google_oauth(
        db=db,
        id_token_str=body.id_token,
        ip_address=_client_ip(request),
        user_agent=request.headers.get("user-agent"),
    )
    return AuthResponse(
        user=AuthUserOut.model_validate(result["user"]),
        access_token=result["access_token"],
        refresh_token=result["refresh_token"],
        expires_at=result["expires_at"],
        is_new_user=result["is_new_user"],
    )


@router.post(
    "/oauth/apple",
    response_model=AuthResponse,
    summary="Sign in with Apple (identity token from client)",
)
@limiter.limit("20/minute")
async def apple_sign_in(request: Request, body: AppleSignInRequest, db: DB):
    result = await auth_service.login_apple_sign_in(
        db=db,
        identity_token=body.identity_token,
        full_name=body.full_name,
        ip_address=_client_ip(request),
        user_agent=request.headers.get("user-agent"),
    )
    return AuthResponse(
        user=AuthUserOut.model_validate(result["user"]),
        access_token=result["access_token"],
        refresh_token=result["refresh_token"],
        expires_at=result["expires_at"],
        is_new_user=result["is_new_user"],
    )


# ── Token operations ───────────────────────────────────────────────────────────

@router.post(
    "/token/refresh",
    response_model=TokenResponse,
    summary="Rotate refresh token - invalidates old pair, issues new pair",
)
@limiter.limit("20/minute")
async def refresh_tokens(request: Request, body: TokenRefreshRequest, db: DB):
    result = await auth_service.refresh_tokens(
        db=db,
        refresh_token=body.refresh_token,
        ip_address=_client_ip(request),
        user_agent=request.headers.get("user-agent"),
    )
    return TokenResponse(
        access_token=result["access_token"],
        refresh_token=result["refresh_token"],
        expires_at=result["expires_at"],
    )


@router.post(
    "/logout",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Revoke session. Pass all_devices=true to revoke all sessions.",
)
@limiter.limit("30/minute")
async def logout(request: Request, body: LogoutRequest, current_user: CurrentUser, db: DB):
    # Extract the raw access token from the Authorization header
    auth_header = request.headers.get("Authorization", "")
    access_token = auth_header.removeprefix("Bearer ").strip()

    await auth_service.logout(
        db=db,
        current_user=current_user,
        access_token=access_token,
        refresh_token=body.refresh_token,
        all_devices=body.all_devices,
    )


# ── Spec-path aliases ─────────────────────────────────────────────────────────

@router.post(
    "/register/phone",
    response_model=AuthResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Complete phone registration after OTP verification (alias for /register)",
    include_in_schema=False,
)
@limiter.limit("10/minute")
async def register_phone_alias(request: Request, body: RegisterRequest, db: DB):
    return await register_phone(request=request, body=body, db=db)


@router.post(
    "/google",
    response_model=AuthResponse,
    summary="Sign in with Google - alias for /oauth/google",
    include_in_schema=False,
)
@limiter.limit("20/minute")
async def google_oauth_alias(request: Request, body: GoogleOAuthRequest, db: DB):
    return await google_oauth(request=request, body=body, db=db)


@router.post(
    "/apple",
    response_model=AuthResponse,
    summary="Sign in with Apple - alias for /oauth/apple",
    include_in_schema=False,
)
@limiter.limit("20/minute")
async def apple_sign_in_alias(request: Request, body: AppleSignInRequest, db: DB):
    return await apple_sign_in(request=request, body=body, db=db)
