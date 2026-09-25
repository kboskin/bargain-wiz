"""The shapes the AI negotiation functions work with: a buyer profile, a screenshot, and
the two kinds of ask (`express_dealmaker` from screenshots, `pro_deal_closer` from a chat).

Pure Python, no SDK imports, so every rule here is unit-testable. A request body becomes one
of these through `Validation.parse` (a 400 when it does not fit); one of these becomes a
prompt through `.prompts.PromptBuilder`.
"""

import base64
import binascii
import re
from typing import ClassVar, Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from core.config import RequestLimits
from core.utils import Text


class ImageMime:
    """The screenshot formats the functions accept."""

    SUPPORTED: ClassVar[frozenset[str]] = frozenset({"image/jpeg", "image/png", "image/webp"})

    @classmethod
    def validate(cls, value: object) -> str:
        mime = str(value or "").lower()
        if mime not in cls.SUPPORTED:
            raise ValueError(f"unsupported image type {mime!r}; use JPEG, PNG or WebP")
        return mime


class Image(BaseModel):
    """`{"mime_type": "image/jpeg", "data": "<base64>"}` → decoded, size-checked bytes."""

    model_config = ConfigDict(frozen=True, extra="ignore")

    mime_type: str
    data: bytes

    @field_validator("mime_type", mode="before")
    @classmethod
    def _mime(cls, value: object) -> str:
        return ImageMime.validate(value)

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
        limit = RequestLimits.current().max_image_bytes
        if len(data) > limit:
            raise ValueError(
                f"each image must be under {limit // 1000} KB; downscale before sending"
            )
        return data

    @property
    def payload_bytes(self) -> int:
        """What this image costs the request body — the cap in MAX_TOTAL_IMAGE_BYTES."""
        return len(self.data)


class StoredImage(BaseModel):
    """A screenshot already in Cloud Storage, handed to the model as a `gs://` URI: a provider
    that reads Cloud Storage (Vertex) fetches it from the bucket instead of this function
    downloading it and sending the bytes again on every turn (AI_INTEGRATION.md).

    **Server-built only.** It is deliberately absent from every request model: a client that
    could name a URI could point the model at any object this function's service account can
    read, so the wire carries base64 and nothing else. [Images.validate] only lets an instance
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
        return ImageMime.validate(value)

    @property
    def payload_bytes(self) -> int:
        """Nothing: the bytes never travel in the request body."""
        return 0


# What a turn can carry: bytes the client just sent, or a screenshot already in the bucket.
Material = Image | StoredImage


class Images:
    """The rules every list of screenshots in a request follows."""

    @staticmethod
    def validate(value: object, *, per: str) -> list:
        """A body may only describe images by their bytes; a [StoredImage] is accepted as an
        already-built object, which only this backend can hand over. At most MAX_IMAGES [per]
        request or message."""
        if value is None:
            return []
        if not isinstance(value, list):
            raise ValueError("must be a list")
        limit = RequestLimits.current().max_images
        if len(value) > limit:
            raise ValueError(f"at most {limit} images per {per}")
        return [
            item if isinstance(item, StoredImage) else Image.model_validate(item) for item in value
        ]

    @staticmethod
    def check_total(images: list[Material]) -> None:
        limit = RequestLimits.current().max_total_image_bytes
        if sum(image.payload_bytes for image in images) > limit:
            raise ValueError(f"images together must be under {limit // 1_000_000} MB")


class Answer(BaseModel):
    """One thing the buyer tapped, and the line the app's template writes for it.

    One entry per *pick*, so a multi-select arrives as several answers sharing a key. That
    is what keeps the sentence attached to the value it describes: a client can restate the
    answer it is sending, and has nowhere to put a line for an option it did not pick.

    Nothing here knows what a key means. `value` is carried so the profile can be stored and
    echoed back; the prompt only ever reads `prompt`.
    """

    model_config = ConfigDict(frozen=True, extra="ignore")

    MAX_KEY_CHARS: ClassVar[int] = 40

    key: str
    value: str | int | float | bool
    prompt: str | None = None

    @field_validator("key", mode="before")
    @classmethod
    def _key(cls, value: object) -> str:
        """Whatever the template named the answer. Unknown keys are the point, not an error."""
        text = Text.clip(value, cls.MAX_KEY_CHARS, ellipsis=False)
        if not text:
            raise ValueError("is required (the answer key the template gave this question)")
        return text.lower()

    @field_validator("prompt", mode="before")
    @classmethod
    def _prompt(cls, value: object) -> str | None:
        """The text is passed through as written, like the chat text — there is no cap, because
        the same client already sends unbounded `text` into the user parts. The only thing
        done to it is collapsing its whitespace, which keeps it to one prompt line; the block
        it lands in is fenced and introduced as data.

        Anything that is not a sentence is dropped rather than rejected: an undescribed
        answer costs that one line and is logged, exactly as one the template forgot."""
        if not isinstance(value, str) or not value.split():
            return None
        return " ".join(value.split())


class Profile(BaseModel):
    """Buyer profile from onboarding, sent with every AI request (see PROFILE_SYNC.md).

    Every answer is equal here: there is no field this backend recognises and none it
    requires, so a question added to the funnel reaches the prompt with no deploy. The order
    is the app's send order, which is onboarding screen order, and it is the order the buyer
    block reads in."""

    model_config = ConfigDict(extra="ignore")

    # The buyer's device locale reaches the model as the language to write in, so what the
    # client sends is checked to be a BCP-47 tag and nothing else: free text must never enter
    # the prompt.
    LOCALE_TAG: ClassVar[re.Pattern[str]] = re.compile(r"[A-Za-z]{2,3}(?:-[A-Za-z0-9]{2,8}){0,3}")
    MAX_LOCALE_CHARS: ClassVar[int] = 20
    DEFAULT_LOCALE: ClassVar[str] = "en"

    answers: list[Answer] = Field(default_factory=list)
    locale: str = "en"  # BCP-47; the language every user-facing text is written in

    @field_validator("answers", mode="before")
    @classmethod
    def _answers(cls, value: object) -> list:
        """A malformed entry fails the request rather than being skipped. A dropped
        *sentence* costs one line of coaching; a dropped *answer* would change the coaching
        invisibly, which is worse than a 400 the client can see."""
        if value is None:
            return []
        if not isinstance(value, list):
            raise ValueError("must be a list of {key, value, prompt} answers")
        return value

    @field_validator("locale", mode="before")
    @classmethod
    def _locale(cls, value: object) -> str:
        """Any language the model can write: the tag is handed to it as-is, no list to extend.
        A tag we cannot read says the device is odd, not the request — answer in English."""
        tag = Text.clip(value, cls.MAX_LOCALE_CHARS, ellipsis=False) or ""
        return tag if cls.LOCALE_TAG.fullmatch(tag) else cls.DEFAULT_LOCALE

    @property
    def described(self) -> int:
        """How many answers the client described. Zero at steady state on a shipped app means
        the Remote Config template lost its `prompt` keys (AI_INTEGRATION.md)."""
        return sum(1 for answer in self.answers if answer.prompt)


class ExpressRequest(BaseModel):
    """`express_dealmaker` body: screenshots and/or text plus the buyer profile."""

    model_config = ConfigDict(extra="ignore")

    MAX_KEYWORD_CHARS: ClassVar[int] = 120

    profile: Profile = Field(default_factory=Profile)
    images: list[Material] = Field(default_factory=list)
    text: str | None = None
    keyword: str | None = None
    # A redo's previous lines: the new ones must not repeat them.
    replacing: list[str] = Field(default_factory=list)

    @field_validator("images", mode="before")
    @classmethod
    def _images(cls, value: object) -> list:
        return Images.validate(value, per="request")

    @field_validator("replacing", mode="before")
    @classmethod
    def _replacing(cls, value: object) -> list:
        if value is None:
            return []
        if not isinstance(value, list):
            raise ValueError("must be a list of lines")
        return [line for line in (Text.trim(v) for v in value) if line]

    @field_validator("text", mode="before")
    @classmethod
    def _text(cls, value: object) -> str | None:
        return Text.trim(value)

    @field_validator("keyword", mode="before")
    @classmethod
    def _keyword(cls, value: object) -> str | None:
        return Text.clip(value, cls.MAX_KEYWORD_CHARS)

    @model_validator(mode="after")
    def _has_material(self) -> "ExpressRequest":
        Images.check_total(self.images)
        if not self.images and not self.text:
            raise ValueError('provide "images" (screenshots) or "text" (listing / chat text)')
        return self


class ChatMessage(BaseModel):
    model_config = ConfigDict(extra="ignore")

    # Gemini's vocabulary, kept as the stored and wire value ('user' | 'model'). The coach is
    # still "the Wizard" in the product and in the prompt's prose.
    role: Literal["user", "model"] = "user"
    text: str = ""
    images: list[Material] = Field(default_factory=list)

    @field_validator("role", mode="before")
    @classmethod
    def _role(cls, value: object) -> object:
        return "user" if value is None else str(value).lower()

    @field_validator("text", mode="before")
    @classmethod
    def _text(cls, value: object) -> str:
        return Text.trim(value) or ""

    @field_validator("images", mode="before")
    @classmethod
    def _images(cls, value: object) -> list:
        return Images.validate(value, per="message")


class ProRequest(BaseModel):
    """`pro_deal_closer` body: the chat so far plus the buyer profile."""

    model_config = ConfigDict(extra="ignore")

    profile: Profile = Field(default_factory=Profile)
    messages: list[ChatMessage]
    mode: Literal["reply", "options"] = "reply"
    regenerate: bool = False
    # A redo's previous reply: the new one must take another approach.
    replacing: str | None = None

    @field_validator("replacing", mode="before")
    @classmethod
    def _replacing(cls, value: object) -> str | None:
        return Text.trim(value)

    @field_validator("messages", mode="before")
    @classmethod
    def _messages(cls, value: object) -> list:
        if not isinstance(value, list) or not value:
            raise ValueError("must be a non-empty list")
        return value[-RequestLimits.current().max_messages :]

    @field_validator("mode", mode="before")
    @classmethod
    def _mode(cls, value: object) -> object:
        return "reply" if value is None else str(value).lower()

    @model_validator(mode="after")
    def _apply_image_budget(self) -> "ProRequest":
        """Newest attachments matter most: walk backwards so the budget favours them, and
        drop turns that end up with neither text nor images."""
        budget = RequestLimits.current().max_images
        kept: list[ChatMessage] = []
        seen: list[Material] = []
        for message in reversed(self.messages):
            images = message.images[:budget]
            budget -= len(images)
            seen.extend(images)
            Images.check_total(seen)
            if not message.text and not images:
                continue
            kept.append(message.model_copy(update={"images": images}))
        if not kept:
            raise ValueError("messages have no text or images")
        kept.reverse()
        self.messages = kept
        return self
