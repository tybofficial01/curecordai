import hashlib
import secrets
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path

import bcrypt
import structlog
from jose import JWTError, jwt

from app.config import settings

logger = structlog.get_logger()

# Hardcoded, not settings.JWT_ALGORITHM - an operator setting JWT_ALGORITHM=HS256 while
# jwt_public_key (a non-secret PEM) is still used as the verification key would make every
# token forgeable by anyone holding the public key. RS256 is the only algorithm this app issues.
JWT_ALGORITHM = "RS256"


def _sha256(value: str) -> bytes:
    # Pre-hash to 32 bytes so bcrypt's 72-byte limit is never hit
    return hashlib.sha256(value.encode()).digest()


def hash_password(password: str) -> str:
    return bcrypt.hashpw(_sha256(password), bcrypt.gensalt(rounds=12)).decode()


def verify_password(plain: str, hashed: str) -> bool:
    ok = bcrypt.checkpw(_sha256(plain), hashed.encode())
    logger.debug("Password verification", result="match" if ok else "mismatch")
    return ok


def hash_token(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


def hash_otp(otp: str) -> str:
    return bcrypt.hashpw(otp.encode(), bcrypt.gensalt(rounds=12)).decode()


def verify_otp(plain_otp: str, hashed_otp: str) -> bool:
    ok = bcrypt.checkpw(plain_otp.encode(), hashed_otp.encode())
    logger.debug("OTP verification", result="match" if ok else "mismatch")
    return ok


def generate_otp(length: int = 6) -> str:
    """Cryptographically secure numeric OTP."""
    otp = "".join([str(secrets.randbelow(10)) for _ in range(length)])
    logger.debug("OTP generated", length=length)
    return otp


def generate_token(nbytes: int = 32) -> str:
    """Cryptographically secure URL-safe random token."""
    return secrets.token_urlsafe(nbytes)


def create_access_token(user_id: uuid.UUID, role: str) -> tuple[str, datetime]:
    expires_at = datetime.now(timezone.utc) + timedelta(
        minutes=settings.JWT_ACCESS_TOKEN_EXPIRE_MINUTES
    )
    payload = {
        "sub": str(user_id),
        "role": role,
        "type": "access",
        "exp": expires_at,
        "iat": datetime.now(timezone.utc),
        "jti": str(uuid.uuid4()),
    }
    token = jwt.encode(payload, settings.jwt_private_key, algorithm=JWT_ALGORITHM)
    logger.debug("Access token issued", user_id=str(user_id), role=role, expires_at=expires_at.isoformat())
    return token, expires_at


def create_refresh_token(user_id: uuid.UUID) -> tuple[str, datetime]:
    expires_at = datetime.now(timezone.utc) + timedelta(
        days=settings.JWT_REFRESH_TOKEN_EXPIRE_DAYS
    )
    payload = {
        "sub": str(user_id),
        "type": "refresh",
        "exp": expires_at,
        "iat": datetime.now(timezone.utc),
        "jti": str(uuid.uuid4()),
    }
    token = jwt.encode(payload, settings.jwt_private_key, algorithm=JWT_ALGORITHM)
    logger.debug("Refresh token issued", user_id=str(user_id), expires_at=expires_at.isoformat())
    return token, expires_at


def decode_access_token(token: str) -> dict:
    try:
        payload = jwt.decode(token, settings.jwt_public_key, algorithms=[JWT_ALGORITHM])
        if payload.get("type") != "access":
            raise JWTError("Not an access token")
        return payload
    except JWTError as exc:
        logger.debug("Access token decode failed", error=str(exc))
        raise ValueError(f"Invalid token: {exc}") from exc


def decode_refresh_token(token: str) -> dict:
    try:
        payload = jwt.decode(token, settings.jwt_public_key, algorithms=[JWT_ALGORITHM])
        if payload.get("type") != "refresh":
            raise JWTError("Not a refresh token")
        return payload
    except JWTError as exc:
        logger.debug("Refresh token decode failed", error=str(exc))
        raise ValueError(f"Invalid token: {exc}") from exc
