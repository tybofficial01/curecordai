"""
AWS S3 service - private bucket only.
All files stored under S3 keys; pre-signed URLs generated on-demand (15-min TTL).
Raw S3 URLs are never stored in the database.
"""
import mimetypes
import re
import uuid

import boto3
import structlog
from botocore.exceptions import ClientError

from app.config import settings

logger = structlog.get_logger()

_UNSAFE_FILENAME_CHARS = re.compile(r"[^\w.\-]")


class S3Service:
    def __init__(self) -> None:
        self._client = None

    @property
    def client(self):
        if self._client is None:
            kwargs = {
                "region_name": settings.AWS_DEFAULT_REGION,
            }
            if settings.AWS_ACCESS_KEY_ID:
                kwargs["aws_access_key_id"] = settings.AWS_ACCESS_KEY_ID
                kwargs["aws_secret_access_key"] = settings.AWS_SECRET_ACCESS_KEY
            self._client = boto3.client("s3", **kwargs)
        return self._client

    def generate_object_key(self, user_id: uuid.UUID, category: str, filename: str) -> str:
        """Deterministic path: users/{user_id}/{category}/{uuid}/{filename}"""
        safe_name = _UNSAFE_FILENAME_CHARS.sub("_", filename.strip())[:255] or "file"
        key = f"users/{user_id}/{category}/{uuid.uuid4()}/{safe_name}"
        logger.debug("S3 object key generated", key=key, category=category)
        return key

    async def generate_presigned_upload_url(
        self,
        object_key: str,
        content_type: str,
        expiry_seconds: int | None = None,
    ) -> str:
        """Generate a PUT pre-signed URL for direct client upload."""
        if not settings.AWS_ACCESS_KEY_ID:
            logger.debug("S3 not configured - returning local placeholder upload URL", key=object_key)
            return f"http://localhost:9000/{settings.AWS_S3_BUCKET_NAME}/{object_key}"

        expiry = expiry_seconds or settings.AWS_S3_PRESIGNED_URL_EXPIRY_SECONDS
        try:
            url = self.client.generate_presigned_url(
                "put_object",
                Params={
                    "Bucket": settings.AWS_S3_BUCKET_NAME,
                    "Key": object_key,
                    "ContentType": content_type,
                },
                ExpiresIn=expiry,
            )
            logger.debug("Presigned upload URL generated", key=object_key, expiry_seconds=expiry)
            return url
        except ClientError as exc:
            logger.error("Failed to generate upload URL", key=object_key, error=str(exc))
            raise

    async def generate_presigned_upload_post(
        self,
        object_key: str,
        content_type: str,
        max_size_bytes: int,
        expiry_seconds: int | None = None,
    ) -> dict:
        """
        Presigned POST with a content-length-range policy condition - S3 itself rejects the
        upload if the actual bytes sent exceed max_size_bytes. Unlike a presigned PUT URL
        (generate_presigned_upload_url), which carries no size enforcement at all, this can't
        be bypassed by a client that declares one size and sends another.
        Returns {"url": ..., "fields": {...}} - the caller must POST a multipart/form-data
        request to `url` with every entry in `fields` as a form field, and the file itself as
        the final field named "file" (S3 requires the file to be the last field in the form).
        """
        if not settings.AWS_ACCESS_KEY_ID:
            logger.debug("S3 not configured - returning local placeholder upload POST", key=object_key)
            return {
                "url": f"http://localhost:9000/{settings.AWS_S3_BUCKET_NAME}",
                "fields": {"key": object_key},
            }

        expiry = expiry_seconds or settings.AWS_S3_PRESIGNED_URL_EXPIRY_SECONDS
        try:
            post = self.client.generate_presigned_post(
                Bucket=settings.AWS_S3_BUCKET_NAME,
                Key=object_key,
                Fields={"Content-Type": content_type},
                Conditions=[
                    {"Content-Type": content_type},
                    ["content-length-range", 1, max_size_bytes],
                ],
                ExpiresIn=expiry,
            )
            logger.debug(
                "Presigned upload POST generated", key=object_key, expiry_seconds=expiry, max_size_bytes=max_size_bytes
            )
            return post
        except ClientError as exc:
            logger.error("Failed to generate upload POST", key=object_key, error=str(exc))
            raise

    async def generate_presigned_download_url(
        self,
        object_key: str,
        expiry_seconds: int | None = None,
        download_filename: str | None = None,
    ) -> str:
        """
        Generate a GET pre-signed URL for secure file download (15-min default).
        When download_filename is given, the URL carries a Content-Disposition:
        attachment header so a plain top-level navigation to the URL (no fetch/CORS
        required) downloads the file instead of rendering it inline in the browser.
        """
        if not settings.AWS_ACCESS_KEY_ID:
            logger.debug("S3 not configured - returning local placeholder download URL", key=object_key)
            return f"http://localhost:9000/{settings.AWS_S3_BUCKET_NAME}/{object_key}"

        expiry = expiry_seconds or settings.AWS_S3_PRESIGNED_URL_EXPIRY_SECONDS
        params = {"Bucket": settings.AWS_S3_BUCKET_NAME, "Key": object_key}
        if download_filename:
            safe_name = _UNSAFE_FILENAME_CHARS.sub("_", download_filename.strip())[:255] or "file"
            params["ResponseContentDisposition"] = f'attachment; filename="{safe_name}"'
        try:
            url = self.client.generate_presigned_url(
                "get_object",
                Params=params,
                ExpiresIn=expiry,
            )
            logger.debug("Presigned download URL generated", key=object_key, expiry_seconds=expiry)
            return url
        except ClientError as exc:
            logger.error("Failed to generate download URL", key=object_key, error=str(exc))
            raise

    async def upload_bytes(self, object_key: str, data: bytes, content_type: str) -> bool:
        """Server-side upload for content the backend already holds in memory (e.g. a WhatsApp
        media download) - unlike the presigned PUT/POST flows above, there's no client to hand
        a URL to here. Returns True on success."""
        if not settings.AWS_ACCESS_KEY_ID:
            logger.debug("S3 not configured - skip upload_bytes", key=object_key)
            return True
        try:
            self.client.put_object(
                Bucket=settings.AWS_S3_BUCKET_NAME, Key=object_key, Body=data,
                ContentType=content_type, ServerSideEncryption="AES256",
            )
            logger.debug("S3 object uploaded from bytes", key=object_key, size_bytes=len(data))
            return True
        except ClientError as exc:
            logger.error("Failed to upload object bytes", key=object_key, error=str(exc))
            return False

    async def delete_object(self, object_key: str) -> bool:
        """Hard-delete an object from S3. Returns True on success."""
        if not settings.AWS_ACCESS_KEY_ID:
            logger.info("S3 not configured - skip delete", key=object_key)
            return True

        try:
            self.client.delete_object(Bucket=settings.AWS_S3_BUCKET_NAME, Key=object_key)
            logger.info("S3 object deleted", key=object_key)
            return True
        except ClientError as exc:
            logger.error("Failed to delete S3 object", key=object_key, error=str(exc))
            return False

    async def copy_object(self, source_key: str, dest_key: str) -> bool:
        if not settings.AWS_ACCESS_KEY_ID:
            logger.debug("S3 not configured - skip copy", src=source_key, dst=dest_key)
            return True
        try:
            self.client.copy_object(
                CopySource={"Bucket": settings.AWS_S3_BUCKET_NAME, "Key": source_key},
                Bucket=settings.AWS_S3_BUCKET_NAME,
                Key=dest_key,
                ServerSideEncryption="AES256",
            )
            logger.debug("S3 object copied", src=source_key, dst=dest_key)
            return True
        except ClientError as exc:
            logger.error("Failed to copy S3 object", src=source_key, dst=dest_key, error=str(exc))
            return False


s3_service = S3Service()
