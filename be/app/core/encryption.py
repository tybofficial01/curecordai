import base64
import os

from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from sqlalchemy.types import LargeBinary, TypeDecorator

from app.config import settings

_NONCE_SIZE = 12  # bytes, standard for AES-GCM


def _aesgcm() -> AESGCM:
    key = base64.b64decode(settings.FIELD_ENCRYPTION_KEY)
    if len(key) != 32:
        raise ValueError(
            "FIELD_ENCRYPTION_KEY must decode to exactly 32 bytes for AES-256 "
            f"(got {len(key)}). Generate one with: "
            "python -c \"import base64, os; print(base64.b64encode(os.urandom(32)).decode())\""
        )
    return AESGCM(key)


def encrypt_value(plaintext: str) -> bytes:
    """Encrypt a string with AES-256-GCM. Returns nonce || ciphertext || tag."""
    nonce = os.urandom(_NONCE_SIZE)
    ciphertext = _aesgcm().encrypt(nonce, plaintext.encode("utf-8"), None)
    return nonce + ciphertext


def decrypt_value(blob: bytes) -> str:
    """Reverse of encrypt_value. Raises cryptography.exceptions.InvalidTag on tampering."""
    nonce, ciphertext = blob[:_NONCE_SIZE], blob[_NONCE_SIZE:]
    return _aesgcm().decrypt(nonce, ciphertext, None).decode("utf-8")


class EncryptedString(TypeDecorator):
    """SQLAlchemy column type that transparently applies AES-256-GCM at rest.

    Values are encrypted before hitting the DB and decrypted on load, so the
    application still works with plain strings - only the stored bytes differ.
    """

    impl = LargeBinary
    cache_ok = True

    def process_bind_param(self, value: str | None, dialect) -> bytes | None:
        if value is None:
            return None
        return encrypt_value(value)

    def process_result_value(self, value: bytes | None, dialect) -> str | None:
        if value is None:
            return None
        return decrypt_value(bytes(value))


def encrypted_columns(model) -> set[str]:
    """Names of a model's columns backed by EncryptedString."""
    return {c.name for c in model.__table__.columns if isinstance(c.type, EncryptedString)}


def decrypt_jsonb_row(row: dict, model) -> dict:
    """Decrypt a row produced by a raw ``to_jsonb()``/``table_valued()`` query.

    Those queries build the JSON server-side from the raw column bytes, bypassing
    EncryptedString.process_result_value entirely - Postgres renders a BYTEA value
    as its hex-text form (``\\x...``) rather than decrypting it. This reverses that
    for one row, in place, and returns it.
    """
    for col in encrypted_columns(model):
        value = row.get(col)
        if isinstance(value, str) and value.startswith("\\x"):
            row[col] = decrypt_value(bytes.fromhex(value[2:]))
    return row
