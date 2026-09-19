"""The turn flow: store what the buyer sent, queue the model call, complete the placeholder.

The app never writes to Firestore. It POSTs a turn to the `conversations` function; the
service stores the user turn plus a `pending` wizard placeholder (the typing indicator), hands
the model call to the `generate` task queue and returns the ids straight away. That queue is
the rate limiter: its `RateLimits` cap how fast and how many Gemini calls run across the
project, and its `RetryConfig` retries a failed one. The worker ([ConversationService.generate])
completes the placeholder, and the app follows every step through its Firestore listener, so
no HTTP response waits for the model. "Delete" is an archive: `active: false`, hidden from the
app's query, kept indefinitely: nothing in here deletes a document.
Contract: wizard-app/CONVERSATIONS.md.
"""
import logging
import time
from typing import Any

from core import config
from core.ai.vertex import JsonGenerator
from core.auth.firebase import AuthInfo
from core.errors import BadRequest, NotFound, TurnInProgress, UpstreamError
from core.firestore import DELETE, SERVER_TIME
from core.serialization import jsonable
from core.storage.images import InvalidImage, prepare_image
from core.validation import validate_model
from features.negotiation.domain.lines import (
    EXPRESS_SCHEMA,
    OPTIONS_SCHEMA,
    REPLY_SCHEMA,
    express_result,
    options_result,
    reply_result,
)
from features.negotiation.domain.models import (
    ChatMessage,
    ExpressRequest,
    Image,
    Profile,
    ProRequest,
)
from features.negotiation.domain.prompts import express_parts, pro_parts, system_prompt

from .models import (
    SCHEMA_VERSION,
    ActionBody,
    CreateBody,
    GenerationTask,
    Kind,
    PatchBody,
    TurnBody,
)
from .ports import ConversationStore, Dispatcher

logger = logging.getLogger("conversations")


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


def _ids(cid: str, message_id: str, reply_id: str | None) -> dict:
    """What a write returns: the app subscribes with these and renders what the worker writes."""
    return {"conversation_id": cid, "message_id": message_id, "reply_id": reply_id}


# ── service ───────────────────────────────────────────────────────────────────


class ConversationService:
    def __init__(
        self,
        store: ConversationStore,
        generator: JsonGenerator,
        dispatcher: Dispatcher,
    ):
        self._store = store
        self._generator = generator
        self._dispatcher = dispatcher

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
        """Three paste-ready lines for a wizard reply. `pending_options` is the spinner the
        app can trust across restarts; the lines themselves arrive through the listener."""
        action = validate_model(ActionBody, body, BadRequest)
        uid = auth.uid
        self._conversation(uid, cid)
        target = self._wizard(self._store.list_messages(uid, cid), action.message_id)
        if target.get("pending_options"):
            return {"conversation_id": cid, "message_id": target["id"]}
        if target.get("status") != "done":
            raise BadRequest("Wait for the wizard's reply before asking for options")
        self._store.set_message(
            uid, cid, target["id"],
            {"pending_options": True, "options_error": DELETE, "updated_at": SERVER_TIME},
            merge=True,
        )
        self._store.set_conversation(uid, cid, {"updated_at": SERVER_TIME}, merge=True)
        self._enqueue(uid, cid, target["id"], kind="pro", profile=action, action="options")
        return {"conversation_id": cid, "message_id": target["id"]}

    def redo(self, auth: AuthInfo, cid: str, body: dict) -> dict:
        action = validate_model(ActionBody, body, BadRequest)
        uid = auth.uid
        conversation = self._conversation(uid, cid)
        kind: Kind = "express" if conversation.get("type") == "express" else "pro"
        messages = self._store.list_messages(uid, cid)
        target = self._wizard(messages, action.message_id)
        if conversation.get("active_turn") or target.get("status") == "pending":
            raise TurnInProgress("The wizard is still typing")
        keyword = action.keyword if action.keyword is not None else conversation.get("keyword")
        pending: dict[str, Any] = {
            "status": "pending",
            "revision": int(target.get("revision") or 0) + 1,
            "updated_at": SERVER_TIME,
        }
        if kind == "pro":
            pending["lines"] = DELETE  # the old options no longer match the new reply
        self._store.set_message(uid, cid, target["id"], pending, merge=True)
        patch: dict[str, Any] = {
            "active_turn": {"message_id": target["id"], "since": SERVER_TIME},
            "updated_at": SERVER_TIME,
            "vibe": action.vibe,
        }
        if kind == "express":
            patch["keyword"] = keyword
        self._store.set_conversation(uid, cid, patch, merge=True)
        self._enqueue(uid, cid, target["id"], kind=kind, profile=action, regenerate=True, keyword=keyword)
        return _ids(cid, target["id"], target["id"])

    def patch(self, auth: AuthInfo, cid: str, body: dict) -> dict:
        patch = validate_model(PatchBody, body, BadRequest)
        self._conversation(auth.uid, cid)
        self._store.set_conversation(auth.uid, cid, {**patch.to_patch(), "updated_at": SERVER_TIME}, merge=True)
        return jsonable(self._conversation(auth.uid, cid))

    def archive(self, auth: AuthInfo, cid: str) -> dict:
        """Soft delete: hidden from the app's listener, the document stays. Idempotent."""
        conversation = self._store.get_conversation(auth.uid, cid)
        if conversation is None:
            raise NotFound("No such conversation")
        if conversation.get("active", True):
            self._store.set_conversation(auth.uid, cid, {"active": False, "archived_at": SERVER_TIME, "updated_at": SERVER_TIME}, merge=True)
            logger.info("conversation archived uid=%s cid=%s", auth.uid, cid)
        return {"conversation_id": cid, "active": False}

    # -- the turn --------------------------------------------------------------

    def _turn(self, uid: str, cid: str, kind: Kind, turn: TurnBody) -> dict:
        """Store the user turn and a pending wizard placeholder, then queue the model call."""
        conversation = self._conversation(uid, cid)
        if int(conversation.get("message_count") or 0) >= config.MAX_MESSAGES_PER_CONVERSATION.value:
            raise BadRequest("This deal chat is full; start a new one")
        if conversation.get("active_turn"):
            raise TurnInProgress("The wizard is still typing")
        refs = self._store_images(uid, cid, turn.images)
        user_message = {
            "role": "user",
            "text": turn.text or "",
            "images": refs,
            "status": "done",
            "created_at": SERVER_TIME,
        }
        wizard_message = {
            "role": "wizard",
            "text": "",
            "status": "pending",
            "revision": 0,
            "created_at": SERVER_TIME,
            "updated_at": SERVER_TIME,
        }
        patch: dict[str, Any] = {
            "preview": _preview(turn.text) if turn.text else "Screenshot",
            "vibe": turn.vibe,
            "updated_at": SERVER_TIME,
            "last_message_at": SERVER_TIME,
        }
        if refs and not conversation.get("thumbnail"):
            patch["thumbnail"] = refs[0]
        keyword = turn.keyword if kind == "express" else None
        mid, reply_id = self._store.begin_turn(uid, cid, user_message, wizard_message, patch)
        self._enqueue(uid, cid, reply_id, kind=kind, profile=turn, keyword=keyword)
        logger.info("turn queued uid=%s cid=%s kind=%s images=%d", uid, cid, kind, len(refs))
        return _ids(cid, mid, reply_id)

    def _enqueue(
        self,
        uid: str,
        cid: str,
        message_id: str,
        *,
        kind: Kind,
        profile: Profile,
        action: str = "reply",
        regenerate: bool = False,
        keyword: str | None = None,
    ) -> None:
        self._dispatcher.dispatch(
            GenerationTask(
                uid=uid,
                conversation_id=cid,
                message_id=message_id,
                kind=kind,
                action=action,
                regenerate=regenerate,
                keyword=keyword,
                profile=Profile(**_profile_fields(profile)),
            )
        )

    # -- the worker (runs from the `generate` task queue) ----------------------

    def generate(self, payload: dict, *, attempt: int = 0) -> None:
        """Run one model call and complete the message it belongs to.

        Raises on failure so the queue retries; only the last attempt records the failure for
        the user, so a transient error never flashes an error in the chat.
        """
        task = validate_model(GenerationTask, payload, BadRequest)
        uid, cid, mid = task.uid, task.conversation_id, task.message_id
        if self._store.get_conversation(uid, cid) is None:
            logger.warning("generation for a deleted conversation uid=%s cid=%s", uid, cid)
            return
        messages = self._store.list_messages(uid, cid)
        target = next((m for m in messages if m["id"] == mid), None)
        if target is None:
            logger.warning("generation for a missing message uid=%s cid=%s mid=%s", uid, cid, mid)
            return
        # Options answer about the target reply, so they include it; a reply answers what came
        # before its own placeholder.
        limit = target.get("seq", 0)
        history = [
            m
            for m in messages
            if m.get("status", "done") == "done" and (m["seq"] <= limit if task.action == "options" else m["seq"] < limit)
        ]
        started = time.monotonic()
        try:
            if task.action == "options":
                self._write_options(uid, cid, mid, task, history)
            elif task.kind == "express":
                self._write_express(uid, cid, mid, task, history, started)
            else:
                self._write_reply(uid, cid, mid, task, history, started)
        except Exception as exc:
            final = attempt + 1 >= config.QUEUE_MAX_ATTEMPTS.value
            logger.warning("generation failed uid=%s cid=%s attempt=%d final=%s: %s", uid, cid, attempt + 1, final, exc)
            if final:
                self._record_failure(uid, cid, mid, task, exc)
            raise
        logger.info("generated uid=%s cid=%s action=%s kind=%s", uid, cid, task.action, task.kind)

    def _write_options(self, uid: str, cid: str, mid: str, task: GenerationTask, history: list[dict]) -> None:
        request = self._pro_request(history, task.profile, mode="options", regenerate=False)
        raw = self._generator.generate_json(system=system_prompt(task.profile), parts=pro_parts(request), schema=OPTIONS_SCHEMA)
        self._store.set_message(
            uid, cid, mid,
            {"lines": options_result(raw)["lines"], "pending_options": DELETE, "updated_at": SERVER_TIME},
            merge=True,
        )
        self._store.set_conversation(uid, cid, {"updated_at": SERVER_TIME}, merge=True)

    def _write_express(self, uid: str, cid: str, mid: str, task: GenerationTask, history: list[dict], started: float) -> None:
        request = self._express_request(history, task.profile, task.keyword)
        raw = self._generator.generate_json(system=system_prompt(task.profile), parts=express_parts(request), schema=EXPRESS_SCHEMA)
        result = express_result(raw)
        images = [ref for m in history for ref in (m.get("images") or [])]
        self._complete(
            uid, cid, mid, started,
            message={"text": result["seeing"], "seeing": result["seeing"], "lines": result["lines"]},
            conversation={
                "express": {"seeing": result["seeing"], "lines": result["lines"], "keyword": task.keyword, "images": images},
                "title": derive_title(seeing=result["seeing"], has_images=bool(images)),
                "preview": _preview(result["lines"][0]["text"]),
            },
        )

    def _write_reply(self, uid: str, cid: str, mid: str, task: GenerationTask, history: list[dict], started: float) -> None:
        request = self._pro_request(history, task.profile, mode="reply", regenerate=task.regenerate)
        raw = self._generator.generate_json(system=system_prompt(task.profile), parts=pro_parts(request), schema=REPLY_SCHEMA)
        reply = reply_result(raw)["reply"]
        self._complete(uid, cid, mid, started, message={"text": reply}, conversation={"preview": _preview(reply)})

    def _complete(self, uid: str, cid: str, mid: str, started: float, *, message: dict, conversation: dict) -> None:
        self._store.set_message(
            uid, cid, mid,
            {**message, "status": "done", "error": DELETE, "model": self._generator.model,
             "latency_ms": int((time.monotonic() - started) * 1000), "updated_at": SERVER_TIME},
            merge=True,
        )
        self._store.set_conversation(
            uid, cid,
            {**conversation, "active_turn": DELETE, "last_error": DELETE, "updated_at": SERVER_TIME,
             "last_message_at": SERVER_TIME},
            merge=True,
        )

    def _record_failure(self, uid: str, cid: str, mid: str, task: GenerationTask, exc: Exception) -> None:
        detail = {
            "code": "UPSTREAM_ERROR" if isinstance(exc, UpstreamError) else "INTERNAL",
            "message": "The wizard could not answer. Try again.",
        }
        if task.action == "options":
            self._store.set_message(
                uid, cid, mid, {"pending_options": DELETE, "options_error": detail, "updated_at": SERVER_TIME}, merge=True
            )
            return
        self._store.set_message(uid, cid, mid, {"status": "failed", "error": detail, "updated_at": SERVER_TIME}, merge=True)
        # Also on the conversation: an Express turn is read off the conversation document, so a
        # failure that lives only on the message is invisible to that flow.
        self._store.set_conversation(
            uid, cid, {"active_turn": DELETE, "last_error": detail, "updated_at": SERVER_TIME}, merge=True
        )

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
        conversation = self._store.get_conversation(uid, cid)
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

