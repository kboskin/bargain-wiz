"""Screenshots a turn carried: re-encoded, stored, and referenced from the message."""

import asyncio

from core.errors import BadRequest
from core.storage.images import ImageProcessor, InvalidImage
from features.negotiation.domain.models import Image

from .documents import ImageRef
from .ports import ScreenshotStore


class Screenshots:
    def __init__(self, store: ScreenshotStore, processor: ImageProcessor):
        self._store = store
        self._processor = processor

    async def save(self, uid: str, cid: str, images: list[Image]) -> list[ImageRef]:
        """Each image → a metadata-free JPEG in the bucket, and the ref the message stores. The
        images are re-encoded and uploaded concurrently; the refs keep the order they were sent."""
        return list(await asyncio.gather(*(self._save(uid, cid, image) for image in images)))

    async def _save(self, uid: str, cid: str, image: Image) -> ImageRef:
        try:
            # Pillow is CPU work: off the event loop, so the other uploads keep moving.
            prepared = await asyncio.to_thread(self._processor.prepare, image.data)
        except InvalidImage as exc:
            raise BadRequest(f"images: {exc}") from exc
        return ImageRef(
            path=await self._store.put(uid, cid, prepared.data, prepared.mime_type),
            mime_type=prepared.mime_type,
            width=prepared.width,
            height=prepared.height,
            bytes=len(prepared.data),
        )
