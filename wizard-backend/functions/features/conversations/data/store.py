"""The conversation documents in Firestore (the screenshots are `screenshots.py`).

    users/{uid}                                    the person's profile document (features/profile)
    users/{uid}/conversations/{cid}                summary for the history list (`active` flag)
    users/{uid}/conversations/{cid}/messages/{mid} one bubble per document, ordered by `seq`

Only the functions write; the app listens with owner-only rules. Nothing is ever deleted: the
app archives (`active: false`) and the document stays. Retention, if it is ever wanted, has
`created_at` and `last_message_at` to work from. Messages hold only a screenshot's object path.

Every call goes through the invocation's async client (`core.firestore.FirestoreConnection`),
so the reads of one invocation overlap on its event loop. What comes back is validated into
the domain's models; what goes in is the domain's documents and patches, made plain here.
"""

from typing import Any

from core.errors import NotFound, TurnInProgress
from core.firestore import FirestorePatch, Patch

from ..domain.documents import (
    ConversationDocuments,
    NewConversation,
    NewMessage,
    StoredConversation,
    StoredMessage,
)


class FirestoreConversationStore:
    """`..domain.ports.ConversationStore` on Firestore."""

    def __init__(self, client: Any):
        self._client = client

    @staticmethod
    def _sdk() -> Any:
        # Imported on first use: the Firestore client adds ~0.3 s to a cold start, and the
        # stateless AI functions never touch Firestore.
        from google.cloud import firestore

        return firestore

    @staticmethod
    def _fields(snapshot: Any) -> dict:
        return {**(snapshot.to_dict() or {}), "id": snapshot.id}

    def _conversations(self, uid: str) -> Any:
        return self._client.collection("users").document(uid).collection("conversations")

    def _messages(self, uid: str, cid: str) -> Any:
        return self._conversations(uid).document(cid).collection("messages")

    def new_id(self) -> str:
        """A fresh document id, made locally like the SDK's own."""
        return self._client.collection("users").document().id

    async def get_conversation(self, uid: str, cid: str) -> StoredConversation | None:
        snapshot = await self._conversations(uid).document(cid).get()
        if not snapshot.exists:
            return None
        return StoredConversation.model_validate(self._fields(snapshot))

    async def list_conversations(self, uid: str, *, limit: int) -> list[StoredConversation]:
        firestore = self._sdk()
        query = (
            self._conversations(uid)
            .where(filter=firestore.FieldFilter("active", "==", True))
            .order_by("updated_at", direction=firestore.Query.DESCENDING)
            .limit(limit)
        )
        return [StoredConversation.model_validate(self._fields(s)) for s in await query.get()]

    async def list_messages(self, uid: str, cid: str) -> list[StoredMessage]:
        snapshots = await self._messages(uid, cid).order_by("seq").get()
        return [StoredMessage.model_validate(self._fields(s)) for s in snapshots]

    async def create_conversation(self, uid: str, cid: str, document: NewConversation) -> None:
        await self._conversations(uid).document(cid).set(FirestorePatch.to_sdk(document))

    async def add_message(self, uid: str, cid: str, mid: str, document: NewMessage) -> None:
        await self._messages(uid, cid).document(mid).set(FirestorePatch.to_sdk(document))

    async def merge_conversation(self, uid: str, cid: str, patch: Patch) -> None:
        document = self._conversations(uid).document(cid)
        await document.set(FirestorePatch.to_sdk(patch), merge=True)

    async def merge_message(self, uid: str, cid: str, mid: str, patch: Patch) -> None:
        document = self._messages(uid, cid).document(mid)
        await document.set(FirestorePatch.to_sdk(patch), merge=True)

    async def begin_turn(
        self, uid: str, cid: str, user: NewMessage, reply: NewMessage, patch: Patch
    ) -> tuple[str, str]:
        """One transaction: the SDK re-runs [run] with fresh reads when it contends."""
        firestore = self._sdk()
        conv_ref = self._conversations(uid).document(cid)
        messages = self._messages(uid, cid)

        @firestore.async_transactional
        async def run(tx: Any) -> tuple[str, str]:
            snapshot = await conv_ref.get(transaction=tx)
            if not snapshot.exists:
                raise NotFound("No such conversation")
            conversation = StoredConversation.model_validate(self._fields(snapshot))
            if conversation.active_turn:
                raise TurnInProgress("The wizard is still typing")
            count = conversation.message_count
            user_ref, reply_ref = messages.document(), messages.document()
            tx.set(
                user_ref,
                FirestorePatch.to_sdk(
                    user.model_copy(update={"seq": count + 1, "reply_id": reply_ref.id})
                ),
            )
            tx.set(reply_ref, FirestorePatch.to_sdk(reply.model_copy(update={"seq": count + 2})))
            tx.set(
                conv_ref,
                FirestorePatch.to_sdk(
                    {
                        **patch,
                        "message_count": count + 2,
                        "active_turn": ConversationDocuments.active_turn(reply_ref.id),
                    }
                ),
                merge=True,
            )
            return user_ref.id, reply_ref.id

        return await run(self._client.transaction())
