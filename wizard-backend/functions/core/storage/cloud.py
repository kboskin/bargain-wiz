"""Cloud Storage through the Admin SDK.

Under the emulator the CLI sets STORAGE_EMULATOR_HOST, so the same calls reach the Storage
emulator; nothing here needs to know which one it is talking to.

The Cloud Storage client is synchronous and cached per process by the Admin SDK, which keeps
its connection pool across requests, so its calls run on a worker thread (`asyncio.to_thread`)
rather than blocking the invocation's event loop.
"""

import asyncio
from typing import Any, Protocol

from core.utils import GcsUri


class BlobReader(Protocol):
    async def read(self, uri: str) -> bytes:
        """The bytes of the object at `gs://bucket/path`."""


class CloudStorage:
    """One bucket — the configured one, else the project's default Firebase bucket — resolved
    on first use, plus [read] for an object in any bucket."""

    def __init__(self, bucket_name: str | None = None):
        self._bucket_name = bucket_name
        self._bucket: Any = None

    @staticmethod
    def _sdk() -> Any:
        # Imported on first use: the Cloud Storage client adds ~0.2 s to a cold start, and
        # most functions never touch a bucket.
        from firebase_admin import storage

        return storage

    def _bucket_ref(self) -> Any:
        if self._bucket is None:
            storage = self._sdk()
            self._bucket = (
                storage.bucket(self._bucket_name) if self._bucket_name else storage.bucket()
            )
        return self._bucket

    async def upload(
        self, path: str, data: bytes, content_type: str, *, cache_control: str | None = None
    ) -> None:
        blob = self._bucket_ref().blob(path)
        if cache_control:
            blob.cache_control = cache_control
        await asyncio.to_thread(blob.upload_from_string, data, content_type=content_type)

    def uri(self, path: str) -> str:
        """No I/O: the bucket's name is known without asking the service."""
        return str(GcsUri(bucket=self._bucket_ref().name, path=path))

    async def read(self, uri: str) -> bytes:
        address = GcsUri.parse(uri)
        blob = self._sdk().bucket(address.bucket).blob(address.path)
        return await asyncio.to_thread(blob.download_as_bytes)
