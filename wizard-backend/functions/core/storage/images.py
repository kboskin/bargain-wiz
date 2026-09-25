"""Screenshot re-encoding for stored conversations.

Every image a client sends is decoded with Pillow, bounded to IMAGE_MAX_SIDE pixels and
re-encoded as a plain JPEG before it is stored. That strips EXIF and any other metadata,
rejects files that only *claim* to be images, and keeps Storage and model costs predictable.
"""

import io
from typing import ClassVar

from PIL import Image, UnidentifiedImageError
from pydantic import BaseModel, ConfigDict

from core.config import ImageSettings


class InvalidImage(ValueError):
    """The bytes are not a supported image."""


class PreparedImage(BaseModel):
    model_config = ConfigDict(frozen=True)

    data: bytes
    mime_type: str
    width: int
    height: int


class ImageProcessor:
    """Decode, bound to [ImageSettings.max_side] and re-encode as metadata-free JPEG."""

    MAGIC: ClassVar[tuple[tuple[bytes, str], ...]] = (
        (b"\xff\xd8\xff", "image/jpeg"),
        (b"\x89PNG\r\n\x1a\n", "image/png"),
        (b"RIFF", "image/webp"),  # RIFF....WEBP, checked below
    )
    OUTPUT_MIME: ClassVar[str] = "image/jpeg"

    def __init__(self, settings: ImageSettings):
        self._settings = settings

    @classmethod
    def sniff_mime(cls, data: bytes) -> str | None:
        """The type the bytes actually are, whatever the request claimed."""
        for magic, mime in cls.MAGIC:
            if data.startswith(magic):
                return None if mime == "image/webp" and data[8:12] != b"WEBP" else mime
        return None

    def prepare(self, data: bytes) -> PreparedImage:
        if self.sniff_mime(data) is None:
            raise InvalidImage("not a JPEG, PNG or WebP image")
        try:
            with Image.open(io.BytesIO(data)) as source:
                source.load()
                image = source.convert("RGB")
        except (UnidentifiedImageError, OSError, ValueError) as exc:
            raise InvalidImage("image could not be decoded") from exc
        width, height = image.size
        scale = self._settings.max_side / max(width, height)
        if scale < 1:
            image = image.resize((max(1, round(width * scale)), max(1, round(height * scale))))
        out = io.BytesIO()
        image.save(out, format="JPEG", quality=self._settings.jpeg_quality, optimize=True)
        return PreparedImage(
            data=out.getvalue(),
            mime_type=self.OUTPUT_MIME,
            width=image.size[0],
            height=image.size[1],
        )
