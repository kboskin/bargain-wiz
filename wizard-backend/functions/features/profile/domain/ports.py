"""What the profile service needs from storage (implemented in `..data.store`)."""

from typing import Protocol

from core.firestore import Patch


class ProfileStore(Protocol):
    async def get(self, doc_id: str) -> dict | None:
        """The document at `users/{doc_id}`, or None."""

    async def merge(self, doc_id: str, patch: Patch) -> None:
        """Firestore `set(merge=True)` of [patch]: nested maps merge, markers apply."""
