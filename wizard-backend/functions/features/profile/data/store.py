"""Where profile documents live: `users/{uid}` in Firestore, and an in-memory double.

Both speak the patch markers from `core.firestore` (and [ArrayUnion]) so the merge rules are
the same in a test and in the cloud.
"""
from datetime import UTC, datetime
from typing import Any

from core.firestore import DELETE, SERVER_TIME, to_firestore

from ..domain.profile import ArrayUnion


class InMemoryProfileStore:
    """Test double with Firestore merge semantics for our markers."""

    def __init__(self, clock=lambda: datetime.now(UTC)):
        self.docs: dict[str, dict] = {}
        self._clock = clock

    def get(self, doc_id: str) -> dict | None:
        doc = self.docs.get(doc_id)
        return _deepcopy(doc) if doc is not None else None

    def merge(self, doc_id: str, patch: dict) -> None:
        doc = self.docs.setdefault(doc_id, {})
        self._apply(doc, patch)

    def _apply(self, target: dict, patch: dict) -> None:
        for key, value in patch.items():
            if value is DELETE:
                target.pop(key, None)
            elif value is SERVER_TIME:
                target[key] = self._clock()
            elif isinstance(value, ArrayUnion):
                existing = list(target.get(key) or [])
                target[key] = existing + [v for v in value.values if v not in existing]
            elif isinstance(value, dict):
                child = target.get(key)
                if not isinstance(child, dict):
                    child = target[key] = {}
                self._apply(child, value)
            else:
                target[key] = value


def _deepcopy(value: Any) -> Any:
    if isinstance(value, dict):
        return {k: _deepcopy(v) for k, v in value.items()}
    if isinstance(value, list):
        return [_deepcopy(v) for v in value]
    return value


class FirestoreProfileStore:
    def __init__(self, client=None):
        if client is None:
            from firebase_admin import firestore

            client = firestore.client()
        self._collection = client.collection("users")

    def get(self, doc_id: str) -> dict | None:
        snapshot = self._collection.document(doc_id).get()
        return snapshot.to_dict() if snapshot.exists else None

    def merge(self, doc_id: str, patch: dict) -> None:
        self._collection.document(doc_id).set(self._translate(patch), merge=True)

    @classmethod
    def _translate(cls, value: Any) -> Any:
        from google.cloud import firestore

        if isinstance(value, ArrayUnion):
            return firestore.ArrayUnion(value.values)
        if isinstance(value, dict):
            return {k: cls._translate(v) for k, v in value.items()}
        if isinstance(value, list):
            return [cls._translate(v) for v in value]
        return to_firestore(value)
