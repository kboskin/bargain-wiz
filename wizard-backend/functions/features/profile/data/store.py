"""Where profile documents live: `users/{uid}` in Firestore, through the invocation's async
client (`core.firestore.FirestoreConnection`)."""

from typing import Any

from core.firestore import FirestorePatch, Patch


class FirestoreProfileStore:
    def __init__(self, client: Any):
        self._collection = client.collection("users")

    async def get(self, doc_id: str) -> dict | None:
        snapshot = await self._collection.document(doc_id).get()
        return snapshot.to_dict() if snapshot.exists else None

    async def merge(self, doc_id: str, patch: Patch) -> None:
        await self._collection.document(doc_id).set(FirestorePatch.to_sdk(patch), merge=True)
