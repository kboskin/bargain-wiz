"""The turn flow: store what the buyer sent, queue the model call, return straight away.

The app never writes to Firestore. It POSTs a turn to the `conversations` function; the
service stores the user turn plus a `pending` wizard placeholder (the typing indicator), hands
the model call to the `generate` task queue and returns the ids. That queue is the rate
limiter: its `RateLimits` cap how fast and how many model calls run across the project, and
its `RetryConfig` retries a failed one. The [GenerationWorker] (`worker.py`) completes the
placeholder, and the app follows every step through its Firestore listener, so no HTTP
response waits for the model. "Delete" is an archive: `active: false`, hidden from the app's
query, kept indefinitely — nothing in here deletes a document.
Contract: wizard-app/CONVERSATIONS.md.
"""

import asyncio
from typing import ClassVar

from core.auth.firebase import AuthInfo
from core.config import ConversationSettings
from core.errors import BadRequest, NotFound, TurnInProgress
from core.observability import StructuredLogger
from core.utils import Validation
from features.negotiation.domain.models import Profile
from features.negotiation.domain.prompts import PromptBuilder

from .documents import ConversationDocuments, ConversationPatches, StoredConversation, Summaries
from .history import ChatHistory
from .models import ActionBody, CreateBody, GenerationTask, Kind, PatchBody, TurnBody
from .ports import ConversationStore, Dispatcher
from .screenshots import Screenshots


class ConversationService:
    """Reads and writes for one user's conversations; every write that needs the model ends
    by dispatching a [GenerationTask]."""

    HISTORY_LIMIT: ClassVar[int] = 100  # conversations the history list returns

    def __init__(
        self,
        store: ConversationStore,
        dispatcher: Dispatcher,
        *,
        screenshots: Screenshots,
        prompts: PromptBuilder,
        summaries: Summaries,
        settings: ConversationSettings,
        log: StructuredLogger,
    ):
        self._store = store
        self._dispatcher = dispatcher
        self._screenshots = screenshots
        self._prompts = prompts
        self._summaries = summaries
        self._settings = settings
        self._log = log

    # -- reads -----------------------------------------------------------------

    async def index(self, auth: AuthInfo) -> dict:
        conversations = await self._store.list_conversations(auth.uid, limit=self.HISTORY_LIMIT)
        return {"conversations": [conversation.body() for conversation in conversations]}

    async def get(self, auth: AuthInfo, cid: str) -> dict:
        conversation, messages = await asyncio.gather(
            self._conversation(auth.uid, cid), self._store.list_messages(auth.uid, cid)
        )
        return {**conversation.body(), "messages": [message.body() for message in messages]}

    # -- writes ----------------------------------------------------------------

    async def create(self, auth: AuthInfo, body: dict) -> dict:
        turn = Validation.parse(CreateBody, body)
        cid = self._store.new_id()
        title = self._summaries.title(text=turn.text, has_images=bool(turn.images))
        await self._store.create_conversation(
            auth.uid, cid, ConversationDocuments.conversation(turn, title=title)
        )
        await self._store.add_message(
            auth.uid,
            cid,
            self._store.new_id(),
            ConversationDocuments.system_record(self._prompts.system(turn.profile)),
        )
        self._log.info("conversation created", uid=auth.uid, cid=cid, type=turn.type)
        return await self._turn(auth.uid, cid, turn.type, turn)

    async def send(self, auth: AuthInfo, cid: str, body: dict) -> dict:
        turn = Validation.parse(TurnBody, body)
        if (await self._conversation(auth.uid, cid)).type == "express":
            raise BadRequest(
                "Express deals take no follow-up messages; use redo or start a Pro chat"
            )
        return await self._turn(auth.uid, cid, "pro", turn)

    async def options(self, auth: AuthInfo, cid: str, body: dict) -> dict:
        """Three paste-ready lines for a wizard reply. `pending_options` is the spinner the
        app can trust across restarts; the lines themselves arrive through the listener."""
        action = Validation.parse(ActionBody, body)
        uid = auth.uid
        _, history = await asyncio.gather(self._conversation(uid, cid), self._history(uid, cid))
        target = history.wizard(action.message_id)
        if target.pending_options:
            return {"conversation_id": cid, "message_id": target.id}
        if target.status != "done":
            raise BadRequest("Wait for the wizard's reply before asking for options")
        await self._store.merge_message(
            uid, cid, target.id, ConversationPatches.options_requested()
        )
        await self._store.merge_conversation(uid, cid, ConversationPatches.touched())
        await self._dispatch(
            uid, cid, target.id, kind="pro", profile=action.profile, action="options"
        )
        return {"conversation_id": cid, "message_id": target.id}

    async def redo(self, auth: AuthInfo, cid: str, body: dict) -> dict:
        """Regenerate a wizard message in place: the same document, one revision higher."""
        action = Validation.parse(ActionBody, body)
        uid = auth.uid
        conversation, history = await asyncio.gather(
            self._conversation(uid, cid), self._history(uid, cid)
        )
        kind: Kind = "express" if conversation.type == "express" else "pro"
        target = history.wizard(action.message_id)
        if conversation.active_turn or target.status == "pending":
            raise TurnInProgress("The wizard is still typing")
        keyword = action.keyword if action.keyword is not None else conversation.keyword
        pending = ConversationPatches.redo_requested(target.revision + 1, clear_lines=kind == "pro")
        await self._store.merge_message(uid, cid, target.id, pending)
        started = ConversationPatches.redo_started(
            target.id, overrides=action.overrides, keyword=keyword, express=kind == "express"
        )
        await self._store.merge_conversation(uid, cid, started)
        await self._dispatch(
            uid, cid, target.id, kind=kind, profile=action.profile, regenerate=True, keyword=keyword
        )
        return ConversationDocuments.turn_ids(cid, target.id, target.id)

    async def patch(self, auth: AuthInfo, cid: str, body: dict) -> dict:
        patch = Validation.parse(PatchBody, body)
        await self._conversation(auth.uid, cid)
        await self._store.merge_conversation(
            auth.uid, cid, ConversationPatches.edited(patch.to_patch())
        )
        return (await self._conversation(auth.uid, cid)).body()

    async def archive(self, auth: AuthInfo, cid: str) -> dict:
        """Soft delete: hidden from the app's listener, the document stays. Idempotent."""
        stored = await self._store.get_conversation(auth.uid, cid)
        if stored is None:
            raise NotFound("No such conversation")
        if stored.active:
            await self._store.merge_conversation(auth.uid, cid, ConversationPatches.archived())
            self._log.info("conversation archived", uid=auth.uid, cid=cid)
        return {"conversation_id": cid, "active": False}

    # -- the turn --------------------------------------------------------------

    async def _turn(self, uid: str, cid: str, kind: Kind, turn: TurnBody) -> dict:
        """Store the user turn and a pending wizard placeholder, then queue the model call."""
        conversation = await self._conversation(uid, cid)
        if conversation.message_count >= self._settings.max_messages:
            raise BadRequest("This deal chat is full; start a new one")
        if conversation.active_turn:
            raise TurnInProgress("The wizard is still typing")
        refs = await self._screenshots.save(uid, cid, turn.images)
        patch = ConversationPatches.turn_started(
            preview=self._summaries.preview(turn.text),
            overrides=turn.overrides,
            thumbnail=refs[0] if refs and not conversation.thumbnail else None,
        )
        mid, reply_id = await self._store.begin_turn(
            uid,
            cid,
            ConversationDocuments.user_message(turn.text, refs),
            ConversationDocuments.pending_reply(),
            patch,
        )
        keyword = turn.keyword if kind == "express" else None
        await self._dispatch(uid, cid, reply_id, kind=kind, profile=turn.profile, keyword=keyword)
        self._log.info(
            "turn queued",
            uid=uid,
            cid=cid,
            kind=kind,
            images=len(refs),
            prompts=turn.profile.described,
        )
        return ConversationDocuments.turn_ids(cid, mid, reply_id)

    async def _dispatch(
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
        await self._dispatcher.dispatch(
            GenerationTask(
                uid=uid,
                conversation_id=cid,
                message_id=message_id,
                kind=kind,
                action=action,
                regenerate=regenerate,
                keyword=keyword,
                profile=profile,
            )
        )

    # -- lookups ---------------------------------------------------------------

    async def _conversation(self, uid: str, cid: str) -> StoredConversation:
        """An active conversation of this user; anything else is a 404 (no ownership oracle)."""
        stored = await self._store.get_conversation(uid, cid)
        if stored is None or not stored.active:
            raise NotFound("No such conversation")
        return stored

    async def _history(self, uid: str, cid: str) -> ChatHistory:
        return ChatHistory(await self._store.list_messages(uid, cid))
