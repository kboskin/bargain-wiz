"""Persistence for backend-owned conversations.

Firestore layout (only the functions write; the app listens with owner-only rules):

    users/{uid}                                   the person's profile document (features/profile)
    users/{uid}/conversations/{cid}                summary for the history list (`active` flag)
    users/{uid}/conversations/{cid}/messages/{mid} one bubble per document, ordered by `seq`

Nothing is ever deleted here: the app archives (`active: false`) and the document stays.
Retention, if it is ever wanted, has `created_at` and `last_message_at` to work from — there
is no derived expiry field. Screenshots live in Cloud Storage under
`users/{uid}/conversations/{cid}/`; messages hold only the object path.
Both classes here implement `..domain.ports.ConversationStore`; the in-memory one mirrors
the semantics so the tests need no emulator.
"""
import logging
from datetime import UTC, datetime
from typing import Any

from core import config
from core.errors import NotFound, TurnInProgress
from core.firestore import SERVER_TIME, apply_in_memory, to_firestore

logger = logging.getLogger("conversation_store")


def image_path(uid: str, cid: str, image_id: str) -> str:
    return f"users/{uid}/conversations/{cid}/{image_id}.jpg"


def _active_turn(reply_id: str) -> dict:
    return {"message_id": reply_id, "since": SERVER_TIME}


# ── in-memory double ──────────────────────────────────────────────────────────


class InMemoryConversationStore:
    def __init__(self, clock=lambda: datetime.now(UTC)):
        self._clock = clock
        self.users: dict[str, dict[str, dict]] = {}
        self.images: dict[str, bytes] = {}
        self._seq = 0

    def new_id(self) -> str:
        self._seq += 1
        return f"id{self._seq:04d}"

    def _conv(self, uid: str, cid: str) -> dict | None:
        return self.users.get(uid, {}).get(cid)

    @staticmethod
    def _copy(doc_id: str, doc: dict) -> dict:
        return {**_deepcopy(doc), "id": doc_id}

    def get_conversation(self, uid, cid):
        conv = self._conv(uid, cid)
        return self._copy(cid, conv["doc"]) if conv else None

    def list_conversations(self, uid, *, limit=100):
        docs = [self._copy(cid, c["doc"]) for cid, c in self.users.get(uid, {}).items() if c["doc"].get("active", True)]
        docs.sort(key=lambda d: d.get("updated_at") or datetime.min.replace(tzinfo=UTC), reverse=True)
        return docs[:limit]

    def set_conversation(self, uid, cid, data, *, merge=False):
        conv = self.users.setdefault(uid, {}).setdefault(cid, {"doc": {}, "messages": {}})
        if not merge:
            conv["doc"] = {}
        apply_in_memory(conv["doc"], data, self._clock)

    def list_messages(self, uid, cid):
        conv = self._conv(uid, cid)
        if not conv:
            return []
        return sorted((self._copy(mid, m) for mid, m in conv["messages"].items()), key=lambda d: d.get("seq", 0))

    def set_message(self, uid, cid, mid, data, *, merge=False):
        conv = self._conv(uid, cid)
        if conv is None:
            raise NotFound("No such conversation")
        message = conv["messages"].setdefault(mid, {})
        if not merge:
            message.clear()
        apply_in_memory(message, data, self._clock)

    def begin_turn(self, uid, cid, user_message, wizard_message, patch):
        conv = self._conv(uid, cid)
        if conv is None:
            raise NotFound("No such conversation")
        if conv["doc"].get("active_turn"):
            raise TurnInProgress("The wizard is still typing")
        count = int(conv["doc"].get("message_count") or 0)
        mid, reply_id = self.new_id(), self.new_id()
        self.set_message(uid, cid, mid, {**user_message, "seq": count + 1, "reply_id": reply_id})
        self.set_message(uid, cid, reply_id, {**wizard_message, "seq": count + 2})
        self.set_conversation(
            uid, cid,
            {**patch, "message_count": count + 2, "active_turn": _active_turn(reply_id)},
            merge=True,
        )
        return mid, reply_id

    def put_image(self, uid, cid, image_id, data, mime_type):
        path = image_path(uid, cid, image_id)
        self.images[path] = data
        return path

    def get_image(self, path):
        return self.images.get(path)


def _deepcopy(value: Any) -> Any:
    if isinstance(value, dict):
        return {k: _deepcopy(v) for k, v in value.items()}
    if isinstance(value, list):
        return [_deepcopy(v) for v in value]
    return value


# ── Firestore + Cloud Storage ─────────────────────────────────────────────────


def _with_id(snapshot) -> dict | None:
    if not snapshot.exists:
        return None
    return {**(snapshot.to_dict() or {}), "id": snapshot.id}


class FirestoreConversationStore:
    def __init__(self, client=None, bucket=None):
        if client is None:
            from firebase_admin import firestore

            client = firestore.client()
        self._client = client
        self._bucket = bucket

    def _bucket_ref(self):
        if self._bucket is None:
            from firebase_admin import storage

            name = config.STORAGE_BUCKET.value.strip()
            self._bucket = storage.bucket(name) if name else storage.bucket()
        return self._bucket

    def _user(self, uid: str):
        return self._client.collection("users").document(uid)

    def _conversations(self, uid: str):
        return self._user(uid).collection("conversations")

    def _messages(self, uid: str, cid: str):
        return self._conversations(uid).document(cid).collection("messages")

    def new_id(self) -> str:
        return self._client.collection("users").document().id

    def get_conversation(self, uid, cid):
        return _with_id(self._conversations(uid).document(cid).get())

    def list_conversations(self, uid, *, limit=100):
        from google.cloud.firestore_v1 import Query
        from google.cloud.firestore_v1.base_query import FieldFilter

        query = (
            self._conversations(uid)
            .where(filter=FieldFilter("active", "==", True))
            .order_by("updated_at", direction=Query.DESCENDING)
            .limit(limit)
        )
        return [doc for doc in (_with_id(s) for s in query.stream()) if doc]

    def set_conversation(self, uid, cid, data, *, merge=False):
        self._conversations(uid).document(cid).set(to_firestore(data), merge=merge)

    def list_messages(self, uid, cid):
        return [doc for doc in (_with_id(s) for s in self._messages(uid, cid).order_by("seq").stream()) if doc]

    def set_message(self, uid, cid, mid, data, *, merge=False):
        self._messages(uid, cid).document(mid).set(to_firestore(data), merge=merge)

    def begin_turn(self, uid, cid, user_message, wizard_message, patch):
        from google.cloud import firestore

        conv_ref = self._conversations(uid).document(cid)
        messages = self._messages(uid, cid)
        transaction = self._client.transaction()

        @firestore.transactional
        def run(tx):
            snapshot = conv_ref.get(transaction=tx)
            if not snapshot.exists:
                raise NotFound("No such conversation")
            data = snapshot.to_dict() or {}
            if data.get("active_turn"):
                raise TurnInProgress("The wizard is still typing")
            count = int(data.get("message_count") or 0)
            user_ref, reply_ref = messages.document(), messages.document()
            tx.set(user_ref, to_firestore({**user_message, "seq": count + 1, "reply_id": reply_ref.id}))
            tx.set(reply_ref, to_firestore({**wizard_message, "seq": count + 2}))
            tx.set(
                conv_ref,
                to_firestore({**patch, "message_count": count + 2, "active_turn": _active_turn(reply_ref.id)}),
                merge=True,
            )
            return user_ref.id, reply_ref.id

        return run(transaction)

    def put_image(self, uid, cid, image_id, data, mime_type):
        path = image_path(uid, cid, image_id)
        blob = self._bucket_ref().blob(path)
        blob.cache_control = "private, max-age=31536000"
        blob.upload_from_string(data, content_type=mime_type)
        return path

    def get_image(self, path):
        from google.api_core import exceptions

        try:
            return self._bucket_ref().blob(path).download_as_bytes()
        except exceptions.NotFound:
            return None
