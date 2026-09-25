"""Stored screenshots, for a provider that cannot fetch them itself."""

import asyncio

from core.errors import ConfigError
from core.storage.cloud import BlobReader

from .types import ImagePart, Prompt


class StoredImageInliner:
    """Replaces every `gs://` image of a prompt with its bytes, read through a [BlobReader].
    Vertex reads Cloud Storage itself and never needs this; Ollama does. The downloads run
    concurrently, so a chat with several screenshots waits for the slowest, not the sum."""

    def __init__(self, blobs: BlobReader | None):
        self._blobs = blobs

    async def inline(self, prompt: Prompt) -> Prompt:
        if not any(image.uri for image in prompt.images):
            return prompt
        if self._blobs is None:
            raise ConfigError(
                "a stored screenshot needs its bytes and no blob reader is configured"
            )
        parts = await asyncio.gather(*(self._inlined(part) for part in prompt.parts))
        return prompt.model_copy(update={"parts": list(parts)})

    async def _inlined[P](self, part: P) -> P:
        if not isinstance(part, ImagePart) or not part.uri:
            return part
        return ImagePart(mime_type=part.mime_type, data=await self._blobs.read(part.uri))
