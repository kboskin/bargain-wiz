"""What a conversation write says, and what the queue carries.

Every body starts from the buyer [Profile]: the app sends it with each turn (PROFILE_SYNC.md)
and it is what the prompt is built from. There is no client request id — one turn is
outstanding per conversation at a time, so `active_turn` is the idempotency key.
Contract: wizard-app/CONVERSATIONS.md.
"""

from typing import ClassVar, Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from core.firestore import FieldOp
from core.utils import Text
from features.negotiation.domain.models import Image, Images, Objectives, Profile

Kind = Literal["pro", "express"]

# A conversation-scoped answer's value: the same leaves an `Answer` carries.
OverrideValue = str | int | float | bool


class Overrides:
    """The answers one deal overrides (`{answer key: value}`). Which keys are allowed is the
    app's call — the template marks an answer `scope: "conversation"` — so this end only
    checks the shape."""

    @staticmethod
    def clean(value: object) -> object:
        """The map with its keys normalised, or None when the body says nothing about it."""
        if value is None:
            return None
        if not isinstance(value, dict):
            raise ValueError("must be a map of answer key to value")
        return {str(k).strip().lower(): v for k, v in value.items() if str(k).strip()}


class ActionBody(BaseModel):
    """Every write: the buyer profile that drives the prompt, plus what it acts on.

    There is no client request id. One turn is outstanding at a time (`active_turn` below),
    so nothing needs a key to tell two turns apart; `extra="ignore"` keeps older apps that
    still send `request_id` working.
    """

    model_config = ConfigDict(extra="ignore")

    MAX_ID_CHARS: ClassVar[int] = 120

    profile: Profile = Field(default_factory=Profile)
    overrides: dict[str, OverrideValue] | None = None
    message_id: str | None = None
    keyword: str | None = None

    @field_validator("message_id", "keyword", mode="before")
    @classmethod
    def _short_text(cls, value: object) -> str | None:
        return Text.clip(value, cls.MAX_ID_CHARS)

    @field_validator("overrides", mode="before")
    @classmethod
    def _overrides(cls, value: object) -> object:
        return Overrides.clean(value)


class TurnBody(ActionBody):
    """One turn from the buyer: text and/or screenshots."""

    text: str | None = None
    images: list[Image] = Field(default_factory=list)

    @field_validator("text", mode="before")
    @classmethod
    def _text(cls, value: object) -> str | None:
        return Text.trim(value)

    @field_validator("images", mode="before")
    @classmethod
    def _images(cls, value: object) -> list:
        return Images.validate(value, per="message")

    @model_validator(mode="after")
    def _has_material(self) -> "TurnBody":
        Images.check_total(self.images)
        if not self.images and not self.text:
            raise ValueError("send text or at least one screenshot")
        return self


class CreateBody(TurnBody):
    """`POST /conversations`: the first turn opens the conversation — and may say what the deal
    is for. The objective ([Objectives]) is set here once and stored on the conversation; later
    turns do not carry it."""

    type: Kind = "pro"
    objective: str | None = None

    @field_validator("objective", mode="before")
    @classmethod
    def _objective(cls, value: object) -> str | None:
        return Objectives.clean(value)

    @field_validator("type", mode="before")
    @classmethod
    def _type(cls, value: object) -> object:
        return "pro" if value is None else str(value).lower()


class PatchBody(BaseModel):
    """History metadata the user edits; only sent fields change, null deletes."""

    model_config = ConfigDict(extra="ignore")

    MAX_TITLE_CHARS: ClassVar[int] = 120
    MAX_PRICE_CHARS: ClassVar[int] = 40

    title: str | None = None
    status: Literal["open", "won", "lost"] | None = None
    price_before: str | None = None
    price_after: str | None = None

    # The conversation-scoped answers this deal overrides. Stored, never read back here
    # — see CONVERSATIONS.md.
    overrides: dict[str, OverrideValue] | None = None

    @field_validator("title", mode="before")
    @classmethod
    def _title(cls, value: object) -> str | None:
        return Text.clip(value, cls.MAX_TITLE_CHARS)

    @field_validator("price_before", "price_after", mode="before")
    @classmethod
    def _short(cls, value: object) -> str | None:
        return Text.clip(value, cls.MAX_PRICE_CHARS)

    @field_validator("overrides", mode="before")
    @classmethod
    def _overrides(cls, value: object) -> object:
        return Overrides.clean(value)

    @field_validator("status", mode="before")
    @classmethod
    def _status(cls, value: object) -> object:
        return value.lower() if isinstance(value, str) else value

    def to_patch(self) -> dict:
        return {
            name: FieldOp.DELETE if getattr(self, name) is None else getattr(self, name)
            for name in self.model_fields_set
        }


class GenerationTask(BaseModel):
    """Queue payload: everything the worker needs to finish one wizard message."""

    model_config = ConfigDict(extra="ignore")

    uid: str
    conversation_id: str
    message_id: str
    kind: Kind = "pro"
    action: Literal["reply", "options"] = "reply"
    regenerate: bool = False
    keyword: str | None = None
    profile: Profile
