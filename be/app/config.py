import base64
from functools import lru_cache
from pathlib import Path
from typing import List

from pydantic import PrivateAttr, field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    # ── App ──────────────────────────────────────────────────────
    APP_ENV: str = "development"
    APP_NAME: str = "CurecordAI"
    APP_VERSION: str = "1.0.0"
    APP_DEBUG: bool = False
    SECRET_KEY: str
    ALLOWED_HOSTS: str = "http://localhost:3000"

    # Base64-encoded 32-byte key used for AES-256-GCM encryption of sensitive
    # fields at rest (e.g. OAuth tokens). Generate with:
    # python -c "import base64, os; print(base64.b64encode(os.urandom(32)).decode())"
    FIELD_ENCRYPTION_KEY: str

    # Comma-separated IPs of reverse proxies we trust to set X-Forwarded-For.
    # Empty (default) means: trust nothing, always use the raw socket IP -
    # only populate this once a reverse proxy is actually deployed in front of the API.
    TRUSTED_PROXY_IPS: str = ""

    @model_validator(mode="after")
    def _guard_production_debug(self) -> "Settings":
        if self.APP_ENV == "production" and self.APP_DEBUG:
            raise ValueError(
                "APP_DEBUG must be False when APP_ENV=production - it enables SQL echo "
                "(including bound parameter values, which can include PHI) to logs."
            )
        return self

    @field_validator("FIELD_ENCRYPTION_KEY")
    @classmethod
    def _guard_field_encryption_key(cls, value: str) -> str:
        try:
            decoded = base64.b64decode(value, validate=True)
        except Exception as exc:
            raise ValueError("FIELD_ENCRYPTION_KEY must be valid base64") from exc
        if len(decoded) != 32:
            raise ValueError(
                f"FIELD_ENCRYPTION_KEY must decode to exactly 32 bytes for AES-256 (got {len(decoded)})"
            )
        return value

    @property
    def allowed_origins(self) -> List[str]:
        return [h.strip() for h in self.ALLOWED_HOSTS.split(",")]

    @property
    def trusted_proxy_ips_list(self) -> List[str]:
        return [ip.strip() for ip in self.TRUSTED_PROXY_IPS.split(",") if ip.strip()]

    # ── Database ──────────────────────────────────────────────────
    DATABASE_URL: str
    DATABASE_SSL: bool = False
    DATABASE_POOL_SIZE: int = 10
    DATABASE_MAX_OVERFLOW: int = 20

    # ── JWT ───────────────────────────────────────────────────────
    JWT_PRIVATE_KEY_PATH: str = "./keys/private.pem"
    JWT_PUBLIC_KEY_PATH: str = "./keys/public.pem"
    JWT_ACCESS_TOKEN_EXPIRE_MINUTES: int = 15
    JWT_REFRESH_TOKEN_EXPIRE_DAYS: int = 30
    JWT_ALGORITHM: str = "RS256"

    _jwt_private_key_cache: str | None = PrivateAttr(default=None)
    _jwt_public_key_cache: str | None = PrivateAttr(default=None)

    @property
    def jwt_private_key(self) -> str:
        # Read once, not on every token issue/verify - the key file never changes at runtime.
        if self._jwt_private_key_cache is None:
            self._jwt_private_key_cache = Path(self.JWT_PRIVATE_KEY_PATH).read_text()
        return self._jwt_private_key_cache

    @property
    def jwt_public_key(self) -> str:
        if self._jwt_public_key_cache is None:
            self._jwt_public_key_cache = Path(self.JWT_PUBLIC_KEY_PATH).read_text()
        return self._jwt_public_key_cache

    # ── AWS ───────────────────────────────────────────────────────
    AWS_ACCESS_KEY_ID: str = ""
    AWS_SECRET_ACCESS_KEY: str = ""
    AWS_DEFAULT_REGION: str = "ap-south-1"
    AWS_S3_BUCKET_NAME: str = "curecordai-documents"
    AWS_S3_PRESIGNED_URL_EXPIRY_SECONDS: int = 900

    # ── Twilio ────────────────────────────────────────────────────
    TWILIO_ACCOUNT_SID: str = ""
    TWILIO_AUTH_TOKEN: str = ""
    TWILIO_PHONE_NUMBER: str = ""
    OTP_EXPIRE_MINUTES: int = 10
    OTP_MAX_ATTEMPTS: int = 5
    OTP_LENGTH: int = 6

    # ── WhatsApp (Meta Cloud API) ────────────────────────────────────
    META_WA_APP_SECRET: str = ""
    META_WA_ACCESS_TOKEN: str = ""
    META_WA_PHONE_NUMBER_ID: str = ""
    META_WA_VERIFY_TOKEN: str = ""
    META_WA_API_VERSION: str = "v26.0"
    # How long a first-time confirmation code is valid, and how long a WhatsApp AI-chat
    # session stays "active" for a family member before the next message defaults back to self.
    WA_CONFIRMATION_CODE_EXPIRE_MINUTES: int = 10
    WA_ACTIVE_PROFILE_IDLE_RESET_MINUTES: int = 120
    RATE_LIMIT_WHATSAPP_PER_MINUTE: int = 6

    # ── Soniox (voice note transcription) ────────────────────────────
    SONIOX_API_KEY: str = ""

    # ── SMTP Email ────────────────────────────────────────────────
    EMAIL_HOST: str = ""
    EMAIL_PORT: int = 587
    EMAIL_USE_TLS: bool = True
    EMAIL_HOST_USER: str = ""
    EMAIL_HOST_PASSWORD: str = ""

    # ── OpenRouter ────────────────────────────────────────────────
    OPENROUTER_API_KEY: str = ""
    OPENROUTER_BASE_URL: str = "https://openrouter.ai/api/v1"
    AI_EXTRACTION_MODEL: str = ""
    AI_SUMMARY_MODEL: str = ""
    AI_CHAT_MODEL: str = ""
    AI_EMBEDDING_MODEL: str = "openai/text-embedding-3-small"
    AI_EMBEDDING_DIMENSIONS: int = 1536
    AI_MAX_TOKENS_SUMMARY: int = 1000
    AI_MAX_TOKENS_EXTRACTION: int = 2000
    AI_MAX_TOKENS_CHAT: int = 2000
    AI_MAX_TOKENS_HISTORY_SUMMARY: int = 1500

    # ── Terminology APIs ──────────────────────────────────────────
    # ICD-11 WHO API - register at https://icd.who.int/icdapi
    ICD11_CLIENT_ID: str = ""
    ICD11_CLIENT_SECRET: str = ""

    # ── Google OAuth ──────────────────────────────────────────────
    GOOGLE_CLIENT_ID: str = ""
    GOOGLE_CLIENT_SECRET: str = ""

    # ── Apple Sign In ─────────────────────────────────────────────
    APPLE_CLIENT_ID: str = ""
    APPLE_TEAM_ID: str = ""
    APPLE_KEY_ID: str = ""
    APPLE_PRIVATE_KEY_PATH: str = "./keys/apple_auth.p8"

    # ── SES Email ─────────────────────────────────────────────────
    SES_FROM_EMAIL: str = "noreply@curecordai.com"
    SES_FROM_NAME: str = "CurecordAI"
    CONTACT_INBOX_EMAIL: str = "support@curecordai.com"

    # ── Rate Limiting ─────────────────────────────────────────────
    RATE_LIMIT_OTP_PER_HOUR: int = 5
    RATE_LIMIT_API_PER_MINUTE: int = 100
    RATE_LIMIT_UPLOAD_PER_HOUR: int = 20
    # Shared limiter storage backend - empty means single-process in-memory (dev default).
    # Set to a redis:// URL in any multi-worker/multi-instance deployment, otherwise each
    # process counts independently and the effective limit multiplies with instance count.
    REDIS_URL: str = ""

    # ── Account lockout (independent of source IP - see SECURITY_AUDIT.md H9) ─────
    LOGIN_LOCKOUT_MAX_ATTEMPTS: int = 10
    LOGIN_LOCKOUT_MINUTES: int = 15

    # ── File Upload ───────────────────────────────────────────────
    MAX_FILE_SIZE_MB: int = 50
    ALLOWED_MIME_TYPES: str = "application/pdf,image/jpeg,image/png,image/webp,application/dicom"

    @property
    def allowed_mime_types_list(self) -> List[str]:
        return [m.strip() for m in self.ALLOWED_MIME_TYPES.split(",")]

    # ── QR Sharing ────────────────────────────────────────────────
    QR_SESSION_EXPIRE_MINUTES: int = 10
    # Public, unauthenticated frontend page the QR code/link points doctors to (Next.js /share/{token}).
    WEB_APP_BASE_URL: str = "http://localhost:3000"

    # ── GDPR ──────────────────────────────────────────────────────
    GDPR_ERASURE_GRACE_PERIOD_DAYS: int = 30
    DATA_EXPORT_FILE_EXPIRY_HOURS: int = 48

    # ── Monitoring ────────────────────────────────────────────────
    SENTRY_DSN: str = ""
    LOG_LEVEL: str = "INFO"
    LOG_DIR: str = "./logs"
    LOG_FILE_NAME: str = "curecordai.log"
    LOG_MAX_BYTES: int = 10 * 1024 * 1024
    LOG_BACKUP_COUNT: int = 5

    @property
    def is_production(self) -> bool:
        return self.APP_ENV == "production"

    @property
    def max_file_size_bytes(self) -> int:
        return self.MAX_FILE_SIZE_MB * 1024 * 1024


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
