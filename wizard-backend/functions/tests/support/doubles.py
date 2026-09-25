"""In-memory stand-ins for what the functions keep in Firebase, with the same semantics, so the
tests run the real services without an emulator. Each keeps plain dicts, as Firestore does,
and implements its port's `async` methods the way the Firestore store does: models in and out,
patches made plain with [FirestorePatch] and applied with Firestore's merge rules. The plain
methods beside them (`conversation`, `messages`, `seed_*`, `doc`, …) are for a test to inspect
or arrange the stored data without an event loop. None of them stands in for a model: tests
that need an answer ask the local one (see conftest.py).
"""

from datetime import UTC, datetime
from typing import Any

from firebase_functions import https_fn

from core.auth.firebase import AuthInfo, FirebaseAuthenticator
from core.errors import NotFound, TurnInProgress, Unauthorized
from core.firestore import FieldOp, FirestorePatch, Patch
from core.observability import MetricEvent, Metrics
from core.utils import GcsUri
from features.conversations.data.screenshots import CloudScreenshotStore
from features.conversations.domain.documents import (
    ConversationDocuments,
    NewConversation,
    NewMessage,
    StoredConversation,
    StoredMessage,
)
from features.lines_that_land.domain.content import Category, LinesContent


class FixedClock:
    def __init__(self, now: datetime):
        self._now = now

    def now(self) -> datetime:
        return self._now


class InMemoryPatch:
    """Firestore `set(merge=True)` semantics for plain dicts, with the [FieldOp] markers. A
    patch may hold models, as the domain's do; they are made plain first."""

    @classmethod
    def apply(cls, target: dict, patch: Patch, now: datetime) -> None:
        for key, value in FirestorePatch.plain(patch).items():
            if value is FieldOp.DELETE:
                target.pop(key, None)
            elif value is FieldOp.SERVER_TIME:
                target[key] = now
            elif isinstance(value, dict):
                child = target.get(key)
                if not isinstance(child, dict):
                    child = target[key] = {}
                cls.apply(child, value, now)
            else:
                target[key] = value

    @classmethod
    def copy(cls, value: Any) -> Any:
        if isinstance(value, dict):
            return {k: cls.copy(v) for k, v in value.items()}
        if isinstance(value, list):
            return [cls.copy(v) for v in value]
        return value


class InMemoryConversationStore:
    """`ConversationStore` over dicts, mirroring the Firestore store."""

    HISTORY_LIMIT = 100

    def __init__(self, clock: FixedClock):
        self._clock = clock
        self.users: dict[str, dict[str, dict]] = {}
        self._seq = 0

    def new_id(self) -> str:
        self._seq += 1
        return f"id{self._seq:04d}"

    def _conv(self, uid: str, cid: str) -> dict | None:
        return self.users.get(uid, {}).get(cid)

    @staticmethod
    def _copy(doc_id: str, doc: dict) -> dict:
        return {**InMemoryPatch.copy(doc), "id": doc_id}

    def conversation(self, uid: str, cid: str) -> dict | None:
        conv = self._conv(uid, cid)
        return self._copy(cid, conv["doc"]) if conv else None

    def conversations(self, uid: str, *, limit: int = HISTORY_LIMIT) -> list[dict]:
        docs = [
            self._copy(cid, c["doc"])
            for cid, c in self.users.get(uid, {}).items()
            if c["doc"].get("active", True)
        ]
        docs.sort(
            key=lambda d: d.get("updated_at") or datetime.min.replace(tzinfo=UTC), reverse=True
        )
        return docs[:limit]

    def seed_conversation(self, uid: str, cid: str, data: dict, *, merge: bool = False) -> None:
        conv = self.users.setdefault(uid, {}).setdefault(cid, {"doc": {}, "messages": {}})
        if not merge:
            conv["doc"] = {}
        InMemoryPatch.apply(conv["doc"], data, self._clock.now())

    def messages(self, uid: str, cid: str) -> list[dict]:
        conv = self._conv(uid, cid)
        if not conv:
            return []
        return sorted(
            (self._copy(mid, m) for mid, m in conv["messages"].items()),
            key=lambda d: d.get("seq", 0),
        )

    def seed_message(
        self, uid: str, cid: str, mid: str, data: dict, *, merge: bool = False
    ) -> None:
        conv = self._conv(uid, cid)
        if conv is None:
            raise NotFound("No such conversation")
        message = conv["messages"].setdefault(mid, {})
        if not merge:
            message.clear()
        InMemoryPatch.apply(message, data, self._clock.now())

    # -- the port ----------------------------------------------------------------

    async def get_conversation(self, uid: str, cid: str) -> StoredConversation | None:
        stored = self.conversation(uid, cid)
        return StoredConversation.model_validate(stored) if stored else None

    async def list_conversations(self, uid: str, *, limit: int) -> list[StoredConversation]:
        return [StoredConversation.model_validate(c) for c in self.conversations(uid, limit=limit)]

    async def list_messages(self, uid: str, cid: str) -> list[StoredMessage]:
        return [StoredMessage.model_validate(m) for m in self.messages(uid, cid)]

    async def create_conversation(self, uid: str, cid: str, document: NewConversation) -> None:
        self.seed_conversation(uid, cid, document.fields())

    async def add_message(self, uid: str, cid: str, mid: str, document: NewMessage) -> None:
        self.seed_message(uid, cid, mid, document.fields())

    async def merge_conversation(self, uid: str, cid: str, patch: Patch) -> None:
        self.seed_conversation(uid, cid, patch, merge=True)

    async def merge_message(self, uid: str, cid: str, mid: str, patch: Patch) -> None:
        self.seed_message(uid, cid, mid, patch, merge=True)

    async def begin_turn(
        self, uid: str, cid: str, user: NewMessage, reply: NewMessage, patch: Patch
    ) -> tuple[str, str]:
        conv = self._conv(uid, cid)
        if conv is None:
            raise NotFound("No such conversation")
        if conv["doc"].get("active_turn"):
            raise TurnInProgress("The wizard is still typing")
        count = int(conv["doc"].get("message_count") or 0)
        mid, reply_id = self.new_id(), self.new_id()
        user = user.model_copy(update={"seq": count + 1, "reply_id": reply_id})
        self.seed_message(uid, cid, mid, user.fields())
        self.seed_message(uid, cid, reply_id, reply.model_copy(update={"seq": count + 2}).fields())
        self.seed_conversation(
            uid,
            cid,
            {
                **patch,
                "message_count": count + 2,
                "active_turn": ConversationDocuments.active_turn(reply_id),
            },
            merge=True,
        )
        return mid, reply_id


class InMemoryScreenshotStore:
    """`ScreenshotStore` (and so `BlobReader`) over a dict, with the bucket's path layout."""

    BUCKET = "in-memory"

    def __init__(self):
        self.images: dict[str, bytes] = {}

    def add(self, uid: str, cid: str, data: bytes) -> str:
        path = CloudScreenshotStore.path(uid, cid, f"img{len(self.images) + 1:04d}")
        self.images[path] = data
        return path

    async def put(self, uid: str, cid: str, data: bytes, mime_type: str) -> str:
        return self.add(uid, cid, data)

    def get(self, path: str) -> bytes | None:
        return self.images.get(path)

    def uri(self, path: str) -> str | None:
        return str(GcsUri(bucket=self.BUCKET, path=path)) if path in self.images else None

    async def read(self, uri: str) -> bytes:
        address = GcsUri.parse(uri)
        if address.bucket != self.BUCKET or address.path not in self.images:
            raise NotFound(f"no stored object {uri}")
        return self.images[address.path]


class InMemoryProfileStore:
    def __init__(self, clock: FixedClock):
        self.docs: dict[str, dict] = {}
        self._clock = clock

    def doc(self, doc_id: str) -> dict | None:
        doc = self.docs.get(doc_id)
        return InMemoryPatch.copy(doc) if doc is not None else None

    async def get(self, doc_id: str) -> dict | None:
        return self.doc(doc_id)

    async def merge(self, doc_id: str, patch: Patch) -> None:
        InMemoryPatch.apply(self.docs.setdefault(doc_id, {}), patch, self._clock.now())


class InMemoryLinesStore:
    def __init__(self, clock: FixedClock, content: LinesContent | None = None):
        self.content = content
        self._clock = clock

    def seed(self, categories: list[Category]) -> LinesContent:
        self.content = LinesContent(
            categories=categories, updated_at=self._clock.now(), source="generated"
        )
        return self.content

    async def read(self) -> LinesContent | None:
        return self.content

    async def write(self, categories: list[Category], *, model: str) -> LinesContent:
        return self.seed(categories)


class StaticAuthenticator:
    """A fixed identity (or none). With [invalid_token] any bearer token is rejected; with
    [app_check_ok] False every request fails App Check."""

    def __init__(
        self,
        info: AuthInfo | None = None,
        *,
        invalid_token: bool = False,
        app_check_ok: bool = True,
    ):
        self.info = info
        self.invalid_token = invalid_token
        self.app_check_ok = app_check_ok

    async def optional(self, req: https_fn.Request) -> AuthInfo | None:
        if self.invalid_token and FirebaseAuthenticator.bearer_token(req):
            raise Unauthorized("Invalid Firebase ID token")
        return self.info

    async def require(self, req: https_fn.Request) -> AuthInfo:
        info = await self.optional(req)
        if info is None:
            raise Unauthorized(FirebaseAuthenticator.SIGN_IN_REQUIRED)
        return info

    async def verify_app_check(self, req: https_fn.Request) -> None:
        if not self.app_check_ok:
            raise Unauthorized("App Check token missing")


class InMemoryMetrics(Metrics):
    """Keeps every event, so a test can read what was measured."""

    def __init__(self):
        self.events: list[MetricEvent] = []

    def emit(self, event: MetricEvent) -> None:
        self.events.append(event)

    def of[Event: MetricEvent](self, kind: type[Event]) -> list[Event]:
        return [event for event in self.events if isinstance(event, kind)]
