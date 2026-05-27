import io
import secrets
import string
from uuid import UUID

import boto3
from botocore.client import Config

from app.core.config import settings


class StorageService:
    def __init__(self) -> None:
        self.client = boto3.client(
            "s3",
            endpoint_url=settings.s3_endpoint,
            aws_access_key_id=settings.s3_access_key,
            aws_secret_access_key=settings.s3_secret_key,
            region_name=settings.s3_region,
            config=Config(signature_version="s3v4"),
            use_ssl=settings.s3_use_ssl,
        )
        self.bucket = settings.s3_bucket
        self._ensure_bucket()

    def _ensure_bucket(self) -> None:
        try:
            self.client.head_bucket(Bucket=self.bucket)
        except Exception:
            try:
                self.client.create_bucket(Bucket=self.bucket)
            except Exception:
                pass

    def upload_bytes(self, key: str, data: bytes, content_type: str = "application/octet-stream") -> str:
        self.client.put_object(Bucket=self.bucket, Key=key, Body=data, ContentType=content_type)
        return self.get_public_url(key)

    def upload_file(self, key: str, file_path: str, content_type: str = "application/octet-stream") -> str:
        with open(file_path, "rb") as f:
            return self.upload_bytes(key, f.read(), content_type)

    def get_public_url(self, key: str) -> str:
        base = settings.s3_endpoint.rstrip("/")
        return f"{base}/{self.bucket}/{key}"

    def download_bytes(self, key: str) -> bytes:
        buffer = io.BytesIO()
        self.client.download_fileobj(self.bucket, key, buffer)
        return buffer.getvalue()


def generate_share_code(length: int = 8) -> str:
    alphabet = string.ascii_uppercase + string.digits
    return "".join(secrets.choice(alphabet) for _ in range(length))


storage_service = StorageService()
