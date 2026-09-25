"""What the conversation service and worker need the outside world to provide.

Three ports, each with one job: the documents (Firestore), the screenshots (Cloud Storage) and
the queue (Cloud Tasks). Everything that reaches outside the process is `async`; `new_id` and
`uri` are not, because they compute locally. The implementations live under `..data`; the
tests have in-memory ones with the same semantics, which is what lets them run the whole flow
without Firebase.
"""

from typing import Protocol

from core.firestore import Patch
from core.storage.cloud import BlobReader

from .documents import NewConversation, NewMessage, StoredConversation, StoredMessage
from .models import GenerationTask


class ConversationStore(Protocol):
    """The conversation and message documents, in and out as models: reads come back
    validated, new documents go in whole, and changes go in as merge [Patch]es."""

    def new_id(self) -> str: ...

    async def get_conversation(self, uid: str, cid: str) -> StoredConversation | None: ...

    async def list_conversations(self, uid: str, *, limit: int) -> list[StoredConversation]:
        """Active conversations, newest activity first, at most [limit]."""

    async def list_messages(self, uid: str, cid: str) -> list[StoredMessage]:
        """All messages in `seq` order."""

    async def create_conversation(self, uid: str, cid: str, document: NewConversation) -> None: ...

    async def add_message(self, uid: str, cid: str, mid: str, document: NewMessage) -> None: ...

    async def merge_conversation(self, uid: str, cid: str, patch: Patch) -> None:
        """Firestore `set(merge=True)`: nested maps merge, lists and values replace, markers
        apply."""

    async def merge_message(self, uid: str, cid: str, mid: str, patch: Patch) -> None: ...

    async def begin_turn(
        self, uid: str, cid: str, user: NewMessage, reply: NewMessage, patch: Patch
    ) -> tuple[str, str]:
        """Atomically append the user turn and the pending wizard placeholder, assign `seq`,
        apply [patch] and set `active_turn`. Raises TurnInProgress when a turn is running."""


class ScreenshotStore(BlobReader, Protocol):
    """A conversation's screenshots. The domain never reads the bytes back — the model is
    handed the `gs://` URI, and a provider that cannot fetch it gets the bytes through
    [read], as the model manager's blob reader."""

    async def put(self, uid: str, cid: str, data: bytes, mime_type: str) -> str:
        """Store one screenshot of conversation [cid]; the object path messages refer to it by."""

    def uri(self, path: str) -> str | None:
        """`gs://bucket/path` for a stored object, None for a path that names none."""


class Dispatcher(Protocol):
    async def dispatch(self, task: GenerationTask) -> None:
        """Schedule the model call; in the cloud this returns once the task is queued."""
