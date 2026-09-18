"""Backend-owned conversations: request bodies, the turn flow and the sub-path router.

The app never writes to Firestore. It POSTs a turn to the `conversations` function; the
service stores the user turn plus a `pending` wizard placeholder (the typing indicator), asks
Gemini, and completes the placeholder. The app renders the conversation from a Firestore
listener, so responses only carry ids (plus the express result, shown before the listener
catches up). "Delete" is an archive: `active: false`, hidden from the app's query, gone for
good when the TTL on `expires_at` fires. Contract: wizard-app/CONVERSATIONS.md.
"""
import logging
import re
import time
from datetime import UTC, datetime, timedelta
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

import config
from auth import AuthInfo
from conversation_store import ConversationStore
from errors import BadRequest, NotFound, TurnInProgress, UpstreamError
from images import InvalidImage, prepare_image
from markers import DELETE, SERVER_TIME
from negotiation import (
    EXPRESS_SCHEMA,
    OPTIONS_SCHEMA,
    REPLY_SCHEMA,
    ChatMessage,
    ExpressRequest,
    Image,
    Profile,
    ProRequest,
    express_parts,
    express_result,
    options_result,
    pro_parts,
    reply_result,
    system_prompt,
)
from user_profile import jsonable
from validation import clip_text, validate_model
from vertex import JsonGenerator

logger = logging.getLogger("conversations")

SCHEMA_VERSION = 1
_DOC_ID = re.compile(r"^[A-Za-z0-9_-]{1,64}$")
_REQUEST_ID = re.compile(r"^[A-Za-z0-9_-]{8,64}$")

Kind = Literal["pro", "express"]


# ── bodies ────────────────────────────────────────────────────────────────────


class ActionBody(Profile):
    """Every write: the buyer profile (prompting) plus a client request id (idempotency)."""

    request_id: str
    message_id: str | None = None
    keyword: str | None = None

    @field_validator("request_id", mode="before")
    @classmethod
    def _request_id(cls, value: object) -> str:
        if not isinstance(value, str) or not _REQUEST_ID.match(value.strip()):
            raise ValueError("must be an 8-64 char id (use a UUID)")
        return value.strip()

    @field_validator("message_id", mode="before")
    @classmethod
    def _message_id(cls, value: object) -> str | None:
        if value is None:
            return None
        if not isinstance(value, str) or not _DOC_ID.match(value):
            raise ValueError("is not a message id")
        return value

    @field_validator("keyword", mode="before")
    @classmethod
    def _keyword(cls, value: object) -> str | None:
        return clip_text(value, 120)


class TurnBody(ActionBody):
    """One turn from the buyer: text and/or screenshots."""

    text: str | None = None
    images: list[Image] = Field(default_factory=list)

    @field_validator("text", mode="before")
    @classmethod
    def _text(cls, value: object) -> str | None:
        return clip_text(value, config.MAX_TEXT_CHARS.value)

    @field_validator("images", mode="before")
    @classmethod
    def _images(cls, value: object) -> list:
        if value is None:
            return []
        if not isinstance(value, list):
            raise ValueError("must be a list")
        if len(value) > config.MAX_IMAGES.value:
            raise ValueError(f"at most {config.MAX_IMAGES.value} images per message")
        return value

    @model_validator(mode="after")
    def _has_material(self) -> "TurnBody":
        if sum(len(image.data) for image in self.images) > config.MAX_TOTAL_IMAGE_BYTES.value:
            raise ValueError(f"images together must be under {config.MAX_TOTAL_IMAGE_BYTES.value // 1_000_000} MB")
        if not self.images and not self.text:
            raise ValueError("send text or at least one screenshot")
        return self


class CreateBody(TurnBody):
    """`POST /conversations`: the first turn opens the conversation."""

    type: Kind = "pro"

    @field_validator("type", mode="before")
    @classmethod
    def _type(cls, value: object) -> object:
        return "pro" if value is None else str(value).lower()


class PatchBody(BaseModel):
    """History metadata the user edits; only sent fields change, null deletes."""

    model_config = ConfigDict(extra="ignore")

    title: str | None = None
    status: Literal["open", "won", "lost"] | None = None
    price_before: str | None = None
    price_after: str | None = None
    vibe: str | None = None
    marketplace: str | None = None

    @field_validator("title", mode="before")
    @classmethod
    def _title(cls, value: object) -> str | None:
        return clip_text(value, 120)

    @field_validator("price_before", "price_after", "vibe", "marketplace", mode="before")
    @classmethod
    def _short(cls, value: object) -> str | None:
        return clip_text(value, 40)

    @field_validator("status", mode="before")
    @classmethod
    def _status(cls, value: object) -> object:
        return value.lower() if isinstance(value, str) else value

    def to_patch(self) -> dict:
        return {name: DELETE if getattr(self, name) is None else getattr(self, name) for name in self.model_fields_set}


# ── helpers ───────────────────────────────────────────────────────────────────


def _clip_words(text: str, max_chars: int) -> str:
    text = " ".join(text.split())
    if len(text) <= max_chars:
        return text
    cut = text[:max_chars].rsplit(" ", 1)[0].rstrip(" ,.;:-–—")
    return (cut or text[:max_chars]) + "…"


def derive_title(*, seeing: str | None = None, text: str | None = None, has_images: bool = False) -> str:
    source = (seeing or text or "").strip()
    if source:
        return _clip_words(source, config.TITLE_CHARS.value)
    return "Screenshot deal" if has_images else "New deal"


def _preview(text: str) -> str:
    return _clip_words(text, config.PREVIEW_CHARS.value)


def _profile_fields(model: Profile) -> dict:
    return model.model_dump(include=set(Profile.model_fields))


def _turn_response(cid: str, kind: Kind, reply: dict, *, message_id: str, reply_id: str | None) -> dict:
    response: dict[str, Any] = {"conversation_id": cid, "message_id": message_id, "reply_id": reply_id}
    if kind == "express":
        response["express"] = {"seeing": reply.get("seeing") or "", "lines": reply.get("lines") or []}
    return response


# ── service ───────────────────────────────────────────────────────────────────


class ConversationService:
    def __init__(self, store: ConversationStore, generator: JsonGenerator, clock=lambda: datetime.now(UTC)):
        self._store = store
        self._generator = generator
        self._clock = clock

    # -- reads -----------------------------------------------------------------

    def index(self, auth: AuthInfo) -> dict:
        return {"conversations": jsonable(self._store.list_conversations(auth.uid))}

    def get(self, auth: AuthInfo, cid: str) -> dict:
        conversation = self._conversation(auth.uid, cid)
        return jsonable({**conversation, "messages": self._store.list_messages(auth.uid, cid)})

    # -- writes ----------------------------------------------------------------

    def create(self, auth: AuthInfo, body: dict) -> dict:
        turn = validate_model(CreateBody, body, BadRequest)
        cid = self._store.new_id()
        self._store.set_conversation(
            auth.uid,
            cid,
            {
                "schema_version": SCHEMA_VERSION,
                "type": turn.type,
                "active": True,
                "status": "open",
                "vibe": turn.vibe,
                "marketplace": turn.marketplace,
                "locale": turn.locale,
                "keyword": turn.keyword if turn.type == "express" else None,
                "title": derive_title(text=turn.text, has_images=bool(turn.images)),
                "preview": "",
                "message_count": 0,
                "created_at": SERVER_TIME,
                "updated_at": SERVER_TIME,
                "last_message_at": SERVER_TIME,
                "expires_at": self._expires_at(),
            },
        )
        logger.info("conversation created uid=%s cid=%s type=%s", auth.uid, cid, turn.type)
        return self._turn(auth.uid, cid, turn.type, turn)

    def send(self, auth: AuthInfo, cid: str, body: dict) -> dict:
        turn = validate_model(TurnBody, body, BadRequest)
        if self._conversation(auth.uid, cid).get("type") == "express":
            raise BadRequest("Express deals take no follow-up messages; use redo or start a Pro chat")
        return self._turn(auth.uid, cid, "pro", turn)

    def options(self, auth: AuthInfo, cid: str, body: dict) -> dict:
        action = validate_model(ActionBody, body, BadRequest)
        uid = auth.uid
        self._conversation(uid, cid)
        messages = self._store.list_messages(uid, cid)
        target = self._wizard(messages, action.message_id)
        if target.get("options_request_id") == action.request_id:
            return {"conversation_id": cid, "message_id": target["id"], "lines": target.get("lines") or []}
        if target.get("status") != "done":
            raise BadRequest("Wait for the wizard's reply before asking for options")
        self._store.bump_turns(uid, self._day(), config.MAX_TURNS_PER_DAY.value)
        history = [m for m in messages if m.get("status", "done") == "done" and m["seq"] <= target["seq"]]
        request = self._pro_request(history, action, mode="options", regenerate=False)
        raw = self._generator.generate_json(system=system_prompt(action), parts=pro_parts(request), schema=OPTIONS_SCHEMA)
        lines = options_result(raw)["lines"]
        self._store.set_message(uid, cid, target["id"], {"lines": lines, "options_request_id": action.request_id, "updated_at": SERVER_TIME}, merge=True)
        self._store.set_conversation(uid, cid, {"updated_at": SERVER_TIME}, merge=True)
        return {"conversation_id": cid, "message_id": target["id"], "lines": lines}

    def redo(self, auth: AuthInfo, cid: str, body: dict) -> dict:
        action = validate_model(ActionBody, body, BadRequest)
        uid = auth.uid
        conversation = self._conversation(uid, cid)
        kind: Kind = "express" if conversation.get("type") == "express" else "pro"
        messages = self._store.list_messages(uid, cid)
        target = self._wizard(messages, action.message_id)
        if target.get("redo_request_id") == action.request_id:
            return _turn_response(cid, kind, target, message_id=target["id"], reply_id=target["id"])
        if conversation.get("active_turn") or target.get("status") == "pending":
            raise TurnInProgress("The wizard is still typing")
        self._store.bump_turns(uid, self._day(), config.MAX_TURNS_PER_DAY.value)
        keyword = action.keyword if action.keyword is not None else conversation.get("keyword")
        self._store.set_message(uid, cid, target["id"], {"status": "pending", "redo_request_id": action.request_id, "updated_at": SERVER_TIME}, merge=True)
        patch: dict[str, Any] = {
            "active_turn": {"message_id": target["id"], "request_id": action.request_id, "since": SERVER_TIME},
            "updated_at": SERVER_TIME,
            "vibe": action.vibe,
        }
        if kind == "express":
            patch["keyword"] = keyword
        self._store.set_conversation(uid, cid, patch, merge=True)
        history = [m for m in messages if m.get("status", "done") == "done" and m["seq"] < target["seq"]]
        extra: dict[str, Any] = {"revision": int(target.get("revision") or 0) + 1}
        if kind == "pro":
            extra["lines"] = DELETE
        reply = self._answer(uid, cid, target["id"], kind, action, history, regenerate=True, keyword=keyword, extra=extra)
        return _turn_response(cid, kind, reply, message_id=target["id"], reply_id=target["id"])

    def patch(self, auth: AuthInfo, cid: str, body: dict) -> dict:
        patch = validate_model(PatchBody, body, BadRequest)
        self._conversation(auth.uid, cid)
        self._store.set_conversation(auth.uid, cid, {**patch.to_patch(), "updated_at": SERVER_TIME}, merge=True)
        return jsonable(self._conversation(auth.uid, cid))

    def archive(self, auth: AuthInfo, cid: str) -> dict:
        """Soft delete: hidden from the app's listener, kept until the TTL. Idempotent."""
        conversation = self._store.get_conversation(auth.uid, cid) if _DOC_ID.match(cid) else None
        if conversation is None:
            raise NotFound("No such conversation")
        if conversation.get("active", True):
            self._store.set_conversation(auth.uid, cid, {"active": False, "archived_at": SERVER_TIME, "updated_at": SERVER_TIME}, merge=True)
            logger.info("conversation archived uid=%s cid=%s", auth.uid, cid)
        return {"conversation_id": cid, "active": False}

    # -- the turn --------------------------------------------------------------

    def _turn(self, uid: str, cid: str, kind: Kind, turn: TurnBody) -> dict:
        messages = self._store.list_messages(uid, cid)
        existing = next((m for m in messages if m.get("role") == "user" and m.get("request_id") == turn.request_id), None)
        if existing:
            reply = next((m for m in messages if m["id"] == existing.get("reply_id")), {})
            return _turn_response(cid, kind, reply, message_id=existing["id"], reply_id=existing.get("reply_id"))
        conversation = self._conversation(uid, cid)
        if int(conversation.get("message_count") or 0) >= config.MAX_MESSAGES_PER_CONVERSATION.value:
            raise BadRequest("This deal chat is full; start a new one")
        if conversation.get("active_turn"):
            raise TurnInProgress("The wizard is still typing")
        self._store.bump_turns(uid, self._day(), config.MAX_TURNS_PER_DAY.value)
        refs = self._store_images(uid, cid, turn.images)
        user_message = {
            "role": "user",
            "text": turn.text or "",
            "images": refs,
            "status": "done",
            "request_id": turn.request_id,
            "created_at": SERVER_TIME,
        }
        wizard_message = {
            "role": "wizard",
            "text": "",
            "status": "pending",
            "request_id": turn.request_id,
            "revision": 0,
            "created_at": SERVER_TIME,
            "updated_at": SERVER_TIME,
        }
        patch: dict[str, Any] = {
            "preview": _preview(turn.text) if turn.text else "Screenshot",
            "vibe": turn.vibe,
            "updated_at": SERVER_TIME,
            "last_message_at": SERVER_TIME,
            "expires_at": self._expires_at(),
        }
        if refs and not conversation.get("thumbnail"):
            patch["thumbnail"] = refs[0]
        keyword = turn.keyword if kind == "express" else None
        mid, reply_id = self._store.begin_turn(uid, cid, user_message, wizard_message, patch)
        history = [m for m in messages if m.get("status", "done") == "done"] + [{**user_message, "id": mid, "images": refs}]
        reply = self._answer(uid, cid, reply_id, kind, turn, history, regenerate=False, keyword=keyword, extra={})
        logger.info("turn uid=%s cid=%s kind=%s images=%d", uid, cid, kind, len(refs))
        return _turn_response(cid, kind, reply, message_id=mid, reply_id=reply_id)

    def _answer(self, uid: str, cid: str, reply_id: str, kind: Kind, profile: Profile, history: list[dict], *, regenerate: bool, keyword: str | None, extra: dict) -> dict:
        """Ask the model for the pending wizard message [reply_id] and finish it (done / failed)."""
        started = time.monotonic()
        try:
            system = system_prompt(profile)
            if kind == "express":
                request = self._express_request(history, profile, keyword)
                result = express_result(self._generator.generate_json(system=system, parts=express_parts(request), schema=EXPRESS_SCHEMA))
                message = {"text": result["seeing"], "seeing": result["seeing"], "lines": result["lines"]}
                conversation = {
                    "express": {"seeing": result["seeing"], "lines": result["lines"], "keyword": keyword,
                                "images": [ref for m in history for ref in (m.get("images") or [])]},
                    "title": derive_title(seeing=result["seeing"], has_images=any(m.get("images") for m in history)),
                    "preview": _preview(result["lines"][0]["text"]),
                }
            else:
                request = self._pro_request(history, profile, mode="reply", regenerate=regenerate)
                result = reply_result(self._generator.generate_json(system=system, parts=pro_parts(request), schema=REPLY_SCHEMA))
                message = {"text": result["reply"]}
                conversation = {"preview": _preview(result["reply"])}
        except Exception as exc:
            logger.warning("turn failed uid=%s cid=%s: %s", uid, cid, exc)
            code = "UPSTREAM_ERROR" if isinstance(exc, UpstreamError) else "INTERNAL"
            self._store.set_message(
                uid, cid, reply_id,
                {"status": "failed", "error": {"code": code, "message": "The wizard could not answer. Try again."}, "updated_at": SERVER_TIME},
                merge=True,
            )
            self._store.set_conversation(uid, cid, {"active_turn": DELETE, "updated_at": SERVER_TIME}, merge=True)
            raise
        self._store.set_message(
            uid, cid, reply_id,
            {**message, **extra, "status": "done", "error": DELETE, "model": self._generator.model,
             "latency_ms": int((time.monotonic() - started) * 1000), "updated_at": SERVER_TIME},
            merge=True,
        )
        self._store.set_conversation(
            uid, cid, {**conversation, "active_turn": DELETE, "updated_at": SERVER_TIME, "last_message_at": SERVER_TIME}, merge=True
        )
        return {**message, **{k: v for k, v in extra.items() if v is not DELETE}}

    # -- prompt material -------------------------------------------------------

    def _material(self, history: list[dict]) -> list[ChatMessage]:
        """The stored turns as chat messages, screenshots loaded newest-first within the budget."""
        budget = config.MAX_IMAGES.value
        loaded: dict[str, list[Image]] = {}
        for message in reversed(history):
            images: list[Image] = []
            for ref in message.get("images") or []:
                if budget == 0:
                    break
                data = self._store.get_image(ref.get("path") or "")
                if data:
                    images.append(Image(mime_type=ref.get("mime_type") or "image/jpeg", data=data))
                    budget -= 1
            loaded[message["id"]] = images
        return [ChatMessage(role=m.get("role") or "user", text=m.get("text") or "", images=loaded[m["id"]]) for m in history]

    def _pro_request(self, history: list[dict], profile: Profile, *, mode: str, regenerate: bool) -> ProRequest:
        try:
            return ProRequest(messages=self._material(history), mode=mode, regenerate=regenerate, **_profile_fields(profile))
        except ValueError as exc:
            raise BadRequest(f"nothing to answer yet: {exc}") from exc

    def _express_request(self, history: list[dict], profile: Profile, keyword: str | None) -> ExpressRequest:
        material = self._material(history)
        text = "\n\n".join(m.text for m in material if m.role == "user" and m.text) or None
        try:
            return ExpressRequest(images=[img for m in material for img in m.images], text=text, keyword=keyword, **_profile_fields(profile))
        except ValueError as exc:
            raise BadRequest(f"nothing to analyse: {exc}") from exc

    def _store_images(self, uid: str, cid: str, images: list[Image]) -> list[dict]:
        refs = []
        for image in images:
            try:
                prepared = prepare_image(image.data)
            except InvalidImage as exc:
                raise BadRequest(f"images: {exc}") from exc
            path = self._store.put_image(uid, cid, self._store.new_id(), prepared.data, prepared.mime_type)
            refs.append({"path": path, "mime_type": prepared.mime_type, "width": prepared.width, "height": prepared.height, "bytes": len(prepared.data)})
        return refs

    # -- lookups ---------------------------------------------------------------

    def _conversation(self, uid: str, cid: str) -> dict:
        """An active conversation of this user; anything else is a 404 (no ownership oracle)."""
        conversation = self._store.get_conversation(uid, cid) if _DOC_ID.match(cid) else None
        if conversation is None or not conversation.get("active", True):
            raise NotFound("No such conversation")
        return conversation

    @staticmethod
    def _wizard(messages: list[dict], message_id: str | None) -> dict:
        wizards = [m for m in messages if m.get("role") == "wizard"]
        target = next((m for m in wizards if m["id"] == message_id), None) if message_id else (wizards[-1] if wizards else None)
        if target is None:
            raise NotFound("No such wizard message")
        return target

    def _day(self) -> str:
        return self._clock().astimezone(UTC).strftime("%Y-%m-%d")

    def _expires_at(self) -> datetime:
        return self._clock() + timedelta(days=config.CONVERSATION_RETENTION_DAYS.value)


# ── routing ───────────────────────────────────────────────────────────────────


def dispatch(service: ConversationService, auth: AuthInfo, method: str, path: str, body: dict) -> dict:
    """The payload for `method path` under the `conversations` function (NotFound otherwise).
    A Cloud Function has one URL; the sub-path is matched here."""
    segments = [s for s in path.split("/") if s]
    if segments and segments[0] == "conversations":
        segments = segments[1:]
    match (method.upper(), segments):
        case ("POST", []):
            return service.create(auth, body)
        case ("GET", []):
            return service.index(auth)
        case ("GET", [cid]):
            return service.get(auth, cid)
        case ("PATCH", [cid]):
            return service.patch(auth, cid, body)
        case ("DELETE", [cid]):
            return service.archive(auth, cid)
        case ("POST", [cid, "messages"]):
            return service.send(auth, cid, body)
        case ("POST", [cid, "options"]):
            return service.options(auth, cid, body)
        case ("POST", [cid, "redo"]):
            return service.redo(auth, cid, body)
    raise NotFound(f"No route for {method} /{'/'.join(segments)}")
