"""The documents a conversation is made of: how they read back, and how new ones are written.

Layout and field meanings are the app's contract (wizard-app/CONVERSATIONS.md):

    users/{uid}/conversations/{cid}                 summary for the history list (`active` flag)
    users/{uid}/conversations/{cid}/messages/{mid}  one bubble per document, ordered by `seq`

Everything crossing the store is a model. Reads come back as [StoredConversation] /
[StoredMessage]: typed where the service decides something, and carrying every other field
through untouched (`extra="allow"`). New documents are [NewConversation] / [NewMessage], built
by [ConversationDocuments]; changes are [ConversationPatches], merge patches whose values are
models where the value has a shape ([ImageRef], [TokenUsage], [Line], [ExpressRecord]). The
store turns both into Firestore data, so field names are spelled in one place.
"""

from enum import StrEnum
from typing import Any, ClassVar, Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator

from core.ai import TokenUsage
from core.config import ConversationSettings
from core.firestore import FieldOp, FirestoreDocument, Patch
from core.utils import JsonValue, Text
from features.negotiation.domain.answers import ExpressAnswer, Line

from .models import CreateBody, Kind

Status = Literal["done", "pending", "failed"]


class Role(StrEnum):
    USER = "user"
    # Gemini's word for its own turns, kept as the stored value the app reads.
    WIZARD = "model"
    # Firestore keeps the whole transcript, the configuration included, so a turn can be read
    # back as the model saw it. This row records the system prompt; it is not a turn: never
    # replayed as chat (the prompt carries it as the system instruction), skipped by the app.
    SYSTEM = "system"


class ImageRef(BaseModel):
    """A stored screenshot, as a message (and the conversation's thumbnail) refers to it: the
    object path in the bucket, never the bytes."""

    model_config = ConfigDict(extra="allow", frozen=True)

    path: str
    mime_type: str = "image/jpeg"
    width: int | None = None
    height: int | None = None
    bytes: int | None = None


class ExpressRecord(ExpressAnswer):
    """An Express deal's answer as the conversation keeps it for the Express flow: the answer,
    the keyword it was asked with and the screenshots it read."""

    keyword: str | None = None
    images: list[ImageRef] = Field(default_factory=list)


class _Stored(BaseModel):
    """A stored document as read back: a null field reads as unset, so defaults apply."""

    model_config = ConfigDict(extra="allow", frozen=True)

    id: str

    @model_validator(mode="before")
    @classmethod
    def _nulls_are_unset(cls, data: Any) -> Any:
        return {k: v for k, v in data.items() if v is not None} if isinstance(data, dict) else data

    def body(self) -> dict:
        """What the API returns: the document as stored (defaults the store never wrote
        stay out), datetimes as ISO-8601."""
        return JsonValue.of(self.model_dump(exclude_unset=True))


class StoredConversation(_Stored):
    type: Kind = "pro"
    active: bool = True
    message_count: int = 0
    active_turn: dict | None = None
    keyword: str | None = None
    thumbnail: ImageRef | None = None
    # What the deal is for, as `POST /conversations` stored it (plain text).
    objective: str | None = None


class StoredMessage(_Stored):
    role: str = Role.USER
    text: str = ""
    seq: int = 0
    status: str = "done"
    revision: int = 0
    pending_options: bool = False
    images: list[ImageRef] = Field(default_factory=list)
    # An Express answer's lines, or the options on a Pro reply; `{intent, text, why}` each.
    lines: list[dict] = Field(default_factory=list)

    @property
    def is_wizard(self) -> bool:
        return self.role == Role.WIZARD

    @property
    def line_texts(self) -> list[str]:
        return [str(line.get("text") or "") for line in self.lines if line.get("text")]

    @property
    def is_turn(self) -> bool:
        """A finished user or wizard message: what a prompt may be built from."""
        return self.role != Role.SYSTEM and self.status == "done"


class Summaries:
    """The history list's texts: a title derived from what the deal is about, and a preview of
    the latest message, each cut at a word boundary."""

    SCREENSHOT_TITLE: ClassVar[str] = "Screenshot deal"
    UNTITLED: ClassVar[str] = "New deal"
    SCREENSHOT_PREVIEW: ClassVar[str] = "Screenshot"

    def __init__(self, settings: ConversationSettings):
        self._settings = settings

    def title(
        self, *, seeing: str | None = None, text: str | None = None, has_images: bool = False
    ) -> str:
        source = (seeing or text or "").strip()
        if source:
            return Text.clip_words(source, self._settings.title_chars)
        return self.SCREENSHOT_TITLE if has_images else self.UNTITLED

    def preview(self, text: str | None) -> str:
        return (
            Text.clip_words(text, self._settings.preview_chars) if text else self.SCREENSHOT_PREVIEW
        )


class NewConversation(FirestoreDocument):
    """`users/{uid}/conversations/{cid}` as `POST /conversations` creates it."""

    schema_version: int
    type: Kind
    active: bool = True
    status: Literal["open", "won", "lost"] = "open"
    overrides: dict[str, Any] = Field(default_factory=dict)
    locale: str | None = None
    keyword: str | None = None
    objective: str | None = None
    title: str
    preview: str = ""
    message_count: int = 0
    created_at: FieldOp = FieldOp.SERVER_TIME
    updated_at: FieldOp = FieldOp.SERVER_TIME
    last_message_at: FieldOp = FieldOp.SERVER_TIME


class NewMessage(FirestoreDocument):
    """A message document as it is first written. `seq` (and a user turn's `reply_id`) are
    assigned by the store, inside the transaction that appends the turn."""

    role: Role
    text: str = ""
    status: Status = "done"
    seq: int | None = None
    revision: int | None = None
    images: list[ImageRef] | None = None
    reply_id: str | None = None
    created_at: FieldOp = FieldOp.SERVER_TIME
    updated_at: FieldOp | None = None


class ConversationDocuments:
    """The documents and fragments a turn writes."""

    SCHEMA_VERSION: ClassVar[int] = 1
    FAILURE_MESSAGE: ClassVar[str] = "The wizard could not answer. Try again."

    @classmethod
    def conversation(cls, turn: CreateBody, *, title: str) -> NewConversation:
        return NewConversation(
            schema_version=cls.SCHEMA_VERSION,
            type=turn.type,
            overrides=turn.overrides or {},
            locale=turn.profile.locale,
            keyword=turn.keyword if turn.type == "express" else None,
            objective=turn.objective,
            title=title,
        )

    @staticmethod
    def system_record(system_prompt: str) -> NewMessage:
        """The conversation's opening record: the system prompt its first turn was configured
        with. `seq` 0 puts it before every turn without shifting them, and it stays out of
        `message_count` because it is not a turn and must not count against the chat's cap.

        A snapshot, deliberately: the prompt is rebuilt per turn from the answers that request
        carries, so a later turn can differ (a tone change, or a Remote Config edit). What this
        records is how the conversation started."""
        return NewMessage(role=Role.SYSTEM, text=system_prompt, seq=0)

    @staticmethod
    def user_message(text: str | None, images: list[ImageRef]) -> NewMessage:
        return NewMessage(role=Role.USER, text=text or "", images=images)

    @staticmethod
    def pending_reply() -> NewMessage:
        """The wizard's placeholder: `pending` with no text is the app's typing indicator."""
        return NewMessage(
            role=Role.WIZARD, status="pending", revision=0, updated_at=FieldOp.SERVER_TIME
        )

    @staticmethod
    def active_turn(reply_id: str) -> dict:
        return {"message_id": reply_id, "since": FieldOp.SERVER_TIME}

    @staticmethod
    def turn_ids(cid: str, message_id: str, reply_id: str | None) -> dict:
        """What a write returns: the app subscribes with these and renders what the worker writes."""
        return {"conversation_id": cid, "message_id": message_id, "reply_id": reply_id}

    @classmethod
    def failure(cls, code: str) -> dict:
        """What the app shows for a generation that gave up: a code and a fixed message."""
        return {"code": code, "message": cls.FAILURE_MESSAGE}


class ConversationPatches:
    """Every change the service and the worker make to documents that already exist, named
    for what it means. Each is a merge patch; `updated_at` rides on all of them."""

    @staticmethod
    def usage(usage: TokenUsage | None) -> TokenUsage | FieldOp:
        """A call's token counts as stored on the message it wrote. Unreported usage deletes
        the field, so a redo never keeps the counts of the revision it replaced."""
        return usage if usage is not None else FieldOp.DELETE

    # -- the service -------------------------------------------------------------

    @staticmethod
    def touched() -> Patch:
        return {"updated_at": FieldOp.SERVER_TIME}

    @staticmethod
    def turn_started(*, preview: str, overrides: dict | None, thumbnail: ImageRef | None) -> Patch:
        """The conversation, as a new turn begins (`begin_turn` adds the count and the turn)."""
        patch: Patch = {
            "preview": preview,
            "updated_at": FieldOp.SERVER_TIME,
            "last_message_at": FieldOp.SERVER_TIME,
        }
        if overrides is not None:
            patch["overrides"] = overrides
        if thumbnail is not None:
            patch["thumbnail"] = thumbnail
        return patch

    @staticmethod
    def options_requested() -> Patch:
        """The wizard message: `pending_options` is the spinner the app trusts across restarts."""
        return {
            "pending_options": True,
            "options_error": FieldOp.DELETE,
            "updated_at": FieldOp.SERVER_TIME,
        }

    @staticmethod
    def redo_requested(revision: int, *, clear_lines: bool) -> Patch:
        """The wizard message, back to pending one revision higher. A Pro reply's options no
        longer match the new reply, so they go."""
        patch: Patch = {
            "status": "pending",
            "revision": revision,
            "updated_at": FieldOp.SERVER_TIME,
        }
        if clear_lines:
            patch["lines"] = FieldOp.DELETE
            patch["options_usage"] = FieldOp.DELETE
        return patch

    @staticmethod
    def redo_started(
        message_id: str, *, overrides: dict | None, keyword: str | None, express: bool
    ) -> Patch:
        patch: Patch = {
            "active_turn": ConversationDocuments.active_turn(message_id),
            "updated_at": FieldOp.SERVER_TIME,
        }
        if overrides is not None:
            patch["overrides"] = overrides
        if express:
            patch["keyword"] = keyword
        return patch

    @staticmethod
    def edited(fields: Patch) -> Patch:
        return {**fields, "updated_at": FieldOp.SERVER_TIME}

    @staticmethod
    def archived() -> Patch:
        return {
            "active": False,
            "archived_at": FieldOp.SERVER_TIME,
            "updated_at": FieldOp.SERVER_TIME,
        }

    # -- the worker --------------------------------------------------------------

    @classmethod
    def answered(
        cls, fields: Patch, *, model: str, latency_ms: int, usage: TokenUsage | None
    ) -> Patch:
        """The wizard message, done: its answer, the model that wrote it, how long it took and
        the tokens the call used."""
        return {
            **fields,
            "status": "done",
            "error": FieldOp.DELETE,
            "model": model,
            "latency_ms": latency_ms,
            "usage": cls.usage(usage),
            "updated_at": FieldOp.SERVER_TIME,
        }

    @staticmethod
    def turn_finished(fields: Patch) -> Patch:
        """The conversation, once the turn's answer is written: free for the next turn."""
        return {
            **fields,
            "active_turn": FieldOp.DELETE,
            "last_error": FieldOp.DELETE,
            "updated_at": FieldOp.SERVER_TIME,
            "last_message_at": FieldOp.SERVER_TIME,
        }

    @classmethod
    def options_answered(cls, lines: list[Line], *, usage: TokenUsage | None) -> Patch:
        """The wizard message, with its three lines and the tokens that call used — kept apart
        from `usage`, which is the reply's own call."""
        return {
            "lines": lines,
            "options_usage": cls.usage(usage),
            "pending_options": FieldOp.DELETE,
            "updated_at": FieldOp.SERVER_TIME,
        }

    @staticmethod
    def options_failed(detail: dict) -> Patch:
        return {
            "pending_options": FieldOp.DELETE,
            "options_error": detail,
            "updated_at": FieldOp.SERVER_TIME,
        }

    @staticmethod
    def answer_failed(detail: dict) -> Patch:
        return {"status": "failed", "error": detail, "updated_at": FieldOp.SERVER_TIME}

    @staticmethod
    def turn_failed(detail: dict) -> Patch:
        """The conversation, after the last attempt failed: free again, and the error where an
        Express deal reads it (that flow reads the conversation, not the message)."""
        return {
            "active_turn": FieldOp.DELETE,
            "last_error": detail,
            "updated_at": FieldOp.SERVER_TIME,
        }
