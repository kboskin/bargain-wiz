"""What [service.ConversationService] needs the outside world to provide.

The implementations live under `..data` (Firestore + Cloud Storage, Cloud Tasks); the service
only ever sees these two shapes, which is what lets the tests run the whole flow in memory.
"""
from typing import Protocol

from .models import GenerationTask


class ConversationStore(Protocol):
    def new_id(self) -> str: ...

    def get_conversation(self, uid: str, cid: str) -> dict | None: ...

    def list_conversations(self, uid: str, *, limit: int = 100) -> list[dict]:
        """Active conversations, newest activity first."""

    def set_conversation(self, uid: str, cid: str, data: dict, *, merge: bool = False) -> None: ...

    def list_messages(self, uid: str, cid: str) -> list[dict]:
        """All messages in `seq` order, each with its `id`."""

    def set_message(self, uid: str, cid: str, mid: str, data: dict, *, merge: bool = False) -> None: ...

    def begin_turn(self, uid: str, cid: str, user_message: dict, wizard_message: dict, patch: dict) -> tuple[str, str]:
        """Atomically append the user turn and the pending wizard placeholder, assign `seq`,
        apply [patch] and set `active_turn`. Raises TurnInProgress when a turn is running."""

    def put_image(self, uid: str, cid: str, image_id: str, data: bytes, mime_type: str) -> str: ...

    def get_image(self, path: str) -> bytes | None: ...


class Dispatcher(Protocol):
    def dispatch(self, task: GenerationTask) -> None:
        """Schedule the model call; must not block the caller on the model."""

