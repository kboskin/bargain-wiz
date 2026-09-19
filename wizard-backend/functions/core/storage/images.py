"""Screenshot handling for stored conversations.

Every image a client sends is decoded with Pillow, bounded to IMAGE_MAX_SIDE pixels and re-encoded
as a plain JPEG before it is stored. That strips EXIF and any other metadata, rejects files
that only *claim* to be images, and keeps Storage and model costs predictable.
"""
import io

from pydantic import BaseModel, ConfigDict

from core import config

_MAGIC = (
    (b"\xff\xd8\xff", "image/jpeg"),
    (b"\x89PNG\r\n\x1a\n", "image/png"),
    (b"RIFF", "image/webp"),  # RIFF....WEBP, checked below
)


class InvalidImage(ValueError):
    """The bytes are not a supported image."""


class PreparedImage(BaseModel):
    model_config = ConfigDict(frozen=True)

    data: bytes
    mime_type: str
    width: int
    height: int


def sniff_mime(data: bytes) -> str | None:
    for magic, mime in _MAGIC:
        if data.startswith(magic):
            if mime == "image/webp" and data[8:12] != b"WEBP":
                return None
            return mime
    return None


def prepare_image(data: bytes) -> PreparedImage:
    """Decode, bound to IMAGE_MAX_SIDE and re-encode as metadata-free JPEG."""
    if sniff_mime(data) is None:
        raise InvalidImage("not a JPEG, PNG or WebP image")
    from PIL import Image, UnidentifiedImageError

    try:
        with Image.open(io.BytesIO(data)) as source:
            source.load()
            image = source.convert("RGB")
    except (UnidentifiedImageError, OSError, ValueError) as exc:
        raise InvalidImage("image could not be decoded") from exc
    width, height = image.size
    scale = config.IMAGE_MAX_SIDE.value / max(width, height)
    if scale < 1:
        image = image.resize((max(1, round(width * scale)), max(1, round(height * scale))))
    out = io.BytesIO()
    image.save(out, format="JPEG", quality=config.IMAGE_JPEG_QUALITY.value, optimize=True)
    return PreparedImage(data=out.getvalue(), mime_type="image/jpeg", width=image.size[0], height=image.size[1])
