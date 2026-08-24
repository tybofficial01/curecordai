import re
import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator


_PHONE_RE = re.compile(r"^\+[1-9]\d{6,14}$")


def _validate_phone(v: str) -> str:
    if not _PHONE_RE.match(v):
        raise ValueError("Phone must be E.164 format, e.g. +923001234567")
    return v


# ── OTP ───────────────────────────────────────────────────────────────────────

class OtpSendRequest(BaseModel):
    phone_number: str = Field(..., description="E.164 format: +923001234567")
    purpose: str = Field(..., pattern="^(registration|login|password_reset)$")

    @field_validator("phone_number")
    @classmethod
    def validate_phone(cls, v: str) -> str:
        return _validate_phone(v)


class OtpSendResponse(BaseModel):
    message: str
    expires_in_seconds: int


class OtpVerifyRequest(BaseModel):
    phone_number: str
    otp: str = Field(..., min_length=6, max_length=6, pattern=r"^\d{6}$")
    purpose: str = Field(..., pattern="^(registration|login|password_reset)$")

    @field_validator("phone_number")
    @classmethod
    def validate_phone(cls, v: str) -> str:
        return _validate_phone(v)


class OtpVerifyResponse(BaseModel):
    verified: bool
    # Returned for existing users (login)
    access_token: str | None = None
    refresh_token: str | None = None
    token_type: str = "bearer"
    expires_at: datetime | None = None
    # True when this is a new user (phone not yet registered)
    is_new_user: bool = False
    # Returned only for new users - pass to /auth/register to complete sign-up
    otp_verified_token: str | None = None


# ── Email OTP (verify email ownership before password registration) ──────────

class EmailOtpSendRequest(BaseModel):
    email: EmailStr


class EmailOtpVerifyRequest(BaseModel):
    email: EmailStr
    otp: str = Field(..., min_length=6, max_length=6, pattern=r"^\d{6}$")


class EmailOtpVerifyResponse(BaseModel):
    verified: bool
    # Short-lived token proving this email was OTP-verified - pass to /auth/register/email
    email_verified_token: str


# ── Registration (after OTP verify for new users) ─────────────────────────────

class RegisterRequest(BaseModel):
    full_name: str = Field(..., min_length=2, max_length=255)
    # Short-lived token issued by /otp/verify when is_new_user=True
    otp_verified_token: str


# ── Email + Password ───────────────────────────────────────────────────────────

class EmailLoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=8, max_length=128)
    device_id: str | None = None
    device_name: str | None = None


class EmailRegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=8, max_length=128)
    full_name: str = Field(..., min_length=2, max_length=255)
    # Short-lived token issued by /auth/otp/verify-email - proves email ownership
    email_verified_token: str

    @field_validator("password")
    @classmethod
    def password_strength(cls, v: str) -> str:
        if not re.search(r"[A-Z]", v):
            raise ValueError("Password must contain at least one uppercase letter")
        if not re.search(r"\d", v):
            raise ValueError("Password must contain at least one digit")
        return v


# ── Password reset (email OTP-gated) ───────────────────────────────────────────

class PasswordResetRequestRequest(BaseModel):
    email: EmailStr


class PasswordResetConfirmRequest(BaseModel):
    email: EmailStr
    otp: str = Field(..., min_length=6, max_length=6, pattern=r"^\d{6}$")
    new_password: str = Field(..., min_length=8, max_length=128)

    @field_validator("new_password")
    @classmethod
    def password_strength(cls, v: str) -> str:
        if not re.search(r"[A-Z]", v):
            raise ValueError("Password must contain at least one uppercase letter")
        if not re.search(r"\d", v):
            raise ValueError("Password must contain at least one digit")
        return v


# ── OAuth ─────────────────────────────────────────────────────────────────────

class GoogleOAuthRequest(BaseModel):
    id_token: str  # Google ID token from client


class AppleSignInRequest(BaseModel):
    identity_token: str  # Apple identity token from client
    full_name: str | None = None  # Only sent on first sign-in by Apple


# ── Token operations ───────────────────────────────────────────────────────────

class TokenRefreshRequest(BaseModel):
    refresh_token: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_at: datetime


class LogoutRequest(BaseModel):
    refresh_token: str | None = None
    all_devices: bool = False


# ── Shared response shapes ─────────────────────────────────────────────────────

class AuthUserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    phone_number: str | None
    email: str | None
    auth_provider: str
    is_active: bool
    is_email_verified: bool
    is_phone_verified: bool
    data_region: str
    created_at: datetime


class AuthResponse(BaseModel):
    user: AuthUserOut
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_at: datetime
    # True when this sign-in just created the account (OAuth first-time sign-up) -
    # lets the frontend route straight into onboarding instead of the dashboard.
    is_new_user: bool = False
