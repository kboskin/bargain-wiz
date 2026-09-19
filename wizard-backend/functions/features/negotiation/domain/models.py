"""The shapes the AI negotiation functions work with: a buyer profile, a screenshot, and
the two kinds of ask (`express_dealmaker` from screenshots, `pro_deal_closer` from a chat).

Pure Python, no SDK imports, so every rule here is unit-testable. Turning a request body into
one of these is `..presentation.requests`; turning one into a prompt is `.prompts`.
"""
import base64
import binascii
import re
from typing import Literal

from pydantic import BaseModel, ConfigDict, field_validator, model_validator

from core import config
from core.validation import clip_text, number_or_none, trimmed

SUPPORTED_MIME = {"image/jpeg", "image/png", "image/webp"}

# The buyer's device locale reaches the model as the language to write in, so what the client
# sends is checked to be a BCP-47 tag and nothing else: free text must never enter the prompt.
LOCALE_TAG = re.compile(r"[A-Za-z]{2,3}(?:-[A-Za-z0-9]{2,8}){0,3}")



class Image(BaseModel):
    """`{"mime_type": "image/jpeg", "data": "<base64>"}` → decoded, size-checked bytes."""

    model_config = ConfigDict(frozen=True, extra="ignore")

    mime_type: str
    data: bytes

    @field_validator("mime_type", mode="before")
    @classmethod
    def _mime(cls, value: object) -> str:
        mime = str(value or "").lower()
        if mime not in SUPPORTED_MIME:
            raise ValueError(f"unsupported image type {mime!r}; use JPEG, PNG or WebP")
        return mime

    @field_validator("data", mode="before")
    @classmethod
    def _decode(cls, value: object) -> bytes:
        if isinstance(value, bytes):
            data = value
        elif isinstance(value, str):
            try:
                data = base64.b64decode(value, validate=True)
            except (binascii.Error, ValueError) as exc:
                raise ValueError("image data must be base64") from exc
        else:
            raise ValueError("image data must be base64")
        if not data:
            raise ValueError("image data is empty")
        if len(data) > config.MAX_IMAGE_BYTES.value:
            raise ValueError(f"each image must be under {config.MAX_IMAGE_BYTES.value // 1000} KB; downscale before sending")
        return data

    @property
    def payload_bytes(self) -> int:
        """What this image costs the request body — the cap in [MAX_TOTAL_IMAGE_BYTES]."""
        return len(self.data)


class StoredImage(BaseModel):
    """A screenshot already in Cloud Storage, handed to Gemini as a `gs://` URI so Vertex
    reads it from the bucket instead of this function downloading it and sending the bytes
    again on every turn (AI_INTEGRATION.md).

    **Server-built only.** It is deliberately absent from every request model: a client that
    could name a URI could point the model at any object this function's service account can
    read, so the wire carries base64 and nothing else. `_images` below only lets an instance
    through, never a dict.
    """

    model_config = ConfigDict(frozen=True, extra="ignore")

    uri: str
    mime_type: str

    @field_validator("uri", mode="before")
    @classmethod
    def _uri(cls, value: object) -> str:
        uri = str(value or "")
        if not uri.startswith("gs://"):
            raise ValueError("must be a gs:// URI")
        return uri

    @field_validator("mime_type", mode="before")
    @classmethod
    def _mime(cls, value: object) -> str:
        mime = str(value or "").lower()
        if mime not in SUPPORTED_MIME:
            raise ValueError(f"unsupported image type {mime!r}; use JPEG, PNG or WebP")
        return mime

    @property
    def payload_bytes(self) -> int:
        """Nothing: the bytes never travel in the request, Vertex fetches them itself."""
        return 0


# What a turn can carry: bytes the client just sent, or a screenshot already in the bucket.
Material = Image | StoredImage


class Profile(BaseModel):
    """Buyer profile from onboarding, sent with every AI request (see PROFILE_SYNC.md).
    Unknown values fall back to defaults; only wrong types are rejected."""

    model_config = ConfigDict(extra="ignore")

    vibe: str
    push: int
    marketplace: str | None = None
    deal_size: float | None = None
    locale: str = "en"  # BCP-47; the language every user-facing text is written in
    hurdles: tuple[str, ...] = ()
    deals_per_month: str | None = None

    # `{answer key: {option id: sentence}}` — each answer's contribution to the system
    # prompt, under the same name the app's Remote Config template gives it: `prompt` on the
    # option. The ids live in that template, so the sentence explaining an id travels with
    # it and a new option needs no deploy here (AI_INTEGRATION.md). Absent for an older app,
    # and for an option nobody has described: the tables in prompts.py answer then.
    prompt: dict[str, dict[str, str]] = {}

    @field_validator("vibe", mode="before")
    @classmethod
    def _vibe(cls, value: object) -> str:
        """Any id the app offers; an unknown one still prompts, with the first known tone."""
        text = clip_text(value, 40)
        if not text:
            raise ValueError("is required (the app sends the buyer's tone)")
        return text.lower()

    @field_validator("push", mode="before")
    @classmethod
    def _push(cls, value: object) -> int:
        number = number_or_none(value)
        if number is None:
            raise ValueError("is required (0-100, the buyer's push level)")
        return int(min(100, max(0, number)))

    @field_validator("deal_size", mode="before")
    @classmethod
    def _deal_size(cls, value: object) -> float | None:
        return number_or_none(value)

    @field_validator("marketplace", "deals_per_month", mode="before")
    @classmethod
    def _short_text(cls, value: object) -> str | None:
        return clip_text(value, 40)

    @field_validator("locale", mode="before")
    @classmethod
    def _locale(cls, value: object) -> str:
        """Any language the model can write: the tag is handed to it as-is, no list to extend.
        A tag we cannot read says the device is odd, not the request — answer in English."""
        tag = clip_text(value, 20, ellipsis=False) or ""
        return tag if LOCALE_TAG.fullmatch(tag) else "en"

    @field_validator("hurdles", mode="before")
    @classmethod
    def _hurdles(cls, value: object) -> tuple[str, ...]:
        if value is None:
            return ()
        if not isinstance(value, list | tuple):
            raise ValueError("must be a list of ids")
        return tuple(h.strip().lower() for h in value if isinstance(h, str) and h.strip())[:8]

    @field_validator("prompt", mode="before")
    @classmethod
    def _prompt(cls, value: object) -> dict[str, dict[str, str]]:
        """The shape is checked, the content is not: an answer key this function has never
        heard of is kept — that is how a question added to the funnel reaches the prompt —
        and the text is passed through as written, like the chat text in `trimmed`. Anything
        that is not a description is dropped, so one bad entry costs that line and no more.

        The only thing done to a sentence is collapsing its whitespace, which keeps it to
        one prompt line; the block it lands in is fenced and introduced as data.
        """
        if value is None:
            return {}
        if not isinstance(value, dict):
            raise ValueError("must be a map of answer key to {option id: description}")
        described: dict[str, dict[str, str]] = {}
        for field, table in value.items():
            if not isinstance(field, str) or not isinstance(table, dict):
                continue
            sentences = {
                option.strip().lower(): " ".join(text.split())
                for option, text in table.items()
                if isinstance(option, str) and option.strip() and isinstance(text, str) and text.split()
            }
            if field.strip() and sentences:
                described[field.strip().lower()] = sentences
        return described


def _profile_of(model: Profile) -> Profile:
    return Profile(**{name: getattr(model, name) for name in Profile.model_fields})


class ExpressRequest(Profile):
    """`express_dealmaker` body: screenshots and/or text plus the buyer profile."""

    images: list[Material] = []
    text: str | None = None
    keyword: str | None = None

    @field_validator("images", mode="before")
    @classmethod
    def _images(cls, value: object) -> list:
        """As on [ChatMessage]: a body describes images by their bytes, and only this
        backend can hand over a [StoredImage]."""
        if value is None:
            return []
        if not isinstance(value, list):
            raise ValueError("must be a list")
        if len(value) > config.MAX_IMAGES.value:
            raise ValueError(f"at most {config.MAX_IMAGES.value} images per request")
        return [item if isinstance(item, StoredImage) else Image.model_validate(item) for item in value]

    @field_validator("text", mode="before")
    @classmethod
    def _text(cls, value: object) -> str | None:
        return trimmed(value)

    @field_validator("keyword", mode="before")
    @classmethod
    def _keyword(cls, value: object) -> str | None:
        return clip_text(value, 120)

    @model_validator(mode="after")
    def _has_material(self) -> "ExpressRequest":
        if sum(image.payload_bytes for image in self.images) > config.MAX_TOTAL_IMAGE_BYTES.value:
            raise ValueError(f"images together must be under {config.MAX_TOTAL_IMAGE_BYTES.value // 1_000_000} MB")
        if not self.images and not self.text:
            raise ValueError('provide "images" (screenshots) or "text" (listing / chat text)')
        return self

    @property
    def profile(self) -> Profile:
        return _profile_of(self)


class ChatMessage(BaseModel):
    model_config = ConfigDict(extra="ignore")

    role: Literal["user", "wizard"] = "user"
    text: str = ""
    images: list[Material] = []

    @field_validator("role", mode="before")
    @classmethod
    def _role(cls, value: object) -> object:
        return "user" if value is None else str(value).lower()

    @field_validator("text", mode="before")
    @classmethod
    def _text(cls, value: object) -> str:
        return trimmed(value) or ""

    @field_validator("images", mode="before")
    @classmethod
    def _images(cls, value: object) -> list:
        """A request body may only describe images by their bytes. A [StoredImage] is
        accepted as an already-built object, which only this backend can hand over — see the
        note on that class."""
        if value is None:
            return []
        if not isinstance(value, list):
            raise ValueError("must be a list")
        if len(value) > config.MAX_IMAGES.value:
            raise ValueError(f"at most {config.MAX_IMAGES.value} images per message")
        return [item if isinstance(item, StoredImage) else Image.model_validate(item) for item in value]


class ProRequest(Profile):
    """`pro_deal_closer` body: the chat so far plus the buyer profile."""

    messages: list[ChatMessage]
    mode: Literal["reply", "options"] = "reply"
    regenerate: bool = False

    @field_validator("messages", mode="before")
    @classmethod
    def _messages(cls, value: object) -> list:
        if not isinstance(value, list) or not value:
            raise ValueError("must be a non-empty list")
        return value[-config.MAX_MESSAGES.value:]

    @field_validator("mode", mode="before")
    @classmethod
    def _mode(cls, value: object) -> object:
        return "reply" if value is None else str(value).lower()

    @model_validator(mode="after")
    def _apply_image_budget(self) -> "ProRequest":
        """Newest attachments matter most: walk backwards so the budget favours them, and
        drop turns that end up with neither text nor images."""
        budget, total = config.MAX_IMAGES.value, 0
        kept: list[ChatMessage] = []
        for message in reversed(self.messages):
            images = message.images[:budget]
            budget -= len(images)
            total += sum(image.payload_bytes for image in images)
            if total > config.MAX_TOTAL_IMAGE_BYTES.value:
                raise ValueError(f"images together must be under {config.MAX_TOTAL_IMAGE_BYTES.value // 1_000_000} MB")
            if not message.text and not images:
                continue
            kept.append(message.model_copy(update={"images": images}))
        if not kept:
            raise ValueError("messages have no text or images")
        kept.reverse()
        self.messages = kept
        return self

    @property
    def profile(self) -> Profile:
        return _profile_of(self)

