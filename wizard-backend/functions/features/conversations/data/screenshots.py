"""Where a conversation's screenshots live: `users/{uid}/conversations/{cid}/` in the bucket,
the layout `storage.rules` protects (readable only by that uid)."""

import uuid
from typing import ClassVar

from core.storage.cloud import CloudStorage


class CloudScreenshotStore:
    """`..domain.ports.ScreenshotStore` on Cloud Storage."""

    CACHE_CONTROL: ClassVar[str] = "private, max-age=31536000"

    def __init__(self, storage: CloudStorage):
        self._storage = storage

    @staticmethod
    def path(uid: str, cid: str, image_id: str) -> str:
        return f"users/{uid}/conversations/{cid}/{image_id}.jpg"

    async def put(self, uid: str, cid: str, data: bytes, mime_type: str) -> str:
        path = self.path(uid, cid, uuid.uuid4().hex)
        await self._storage.upload(path, data, mime_type, cache_control=self.CACHE_CONTROL)
        return path

    def uri(self, path: str) -> str | None:
        """Not checked for existence: a missing object costs one failed generation, while a
        `blobs.exists()` per image per turn is the round-trip handing out URIs avoids."""
        return self._storage.uri(path) if path else None

    async def read(self, uri: str) -> bytes:
        return await self._storage.read(uri)
