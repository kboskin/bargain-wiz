"""A conversation's stored messages, and what of them the model gets for one generation."""

from collections.abc import Callable

from core.errors import NotFound
from features.negotiation.domain.models import ChatMessage, StoredImage

from .documents import StoredMessage


class ChatHistory:
    def __init__(self, messages: list[StoredMessage]):
        self._messages = sorted(messages, key=lambda m: m.seq)

    def find(self, message_id: str) -> StoredMessage | None:
        return next((m for m in self._messages if m.id == message_id), None)

    def wizard(self, message_id: str | None) -> StoredMessage:
        """The wizard message [message_id] names, or the latest one; NotFound otherwise."""
        wizards = [m for m in self._messages if m.is_wizard]
        if message_id:
            target = next((m for m in wizards if m.id == message_id), None)
        else:
            target = wizards[-1] if wizards else None
        if target is None:
            raise NotFound("No such wizard message")
        return target

    def turns_for(self, target: StoredMessage, *, include_target: bool) -> list[StoredMessage]:
        """The finished turns a generation for [target] reads. A reply answers what came before
        its own placeholder; options answer about the reply itself, so they include it. The
        system record is never a turn: it already reaches the model as the system prompt."""
        return [
            m
            for m in self._messages
            if m.is_turn and (m.seq <= target.seq if include_target else m.seq < target.seq)
        ]

    @staticmethod
    def as_chat(
        turns: list[StoredMessage], *, uri_of: Callable[[str], str | None], max_images: int
    ) -> list[ChatMessage]:
        """The turns as chat messages, their screenshots referenced newest first within
        [max_images].

        The bytes are not read here: a stored screenshot is referenced by its `gs://` URI,
        which Vertex reads itself, so a long chat does not re-download and re-send the same
        screenshots on every turn. The budget bounds what the model is asked to look at — and
        pays for, since every screenshot in the prompt is billed again on every turn."""
        budget = max_images
        images_of: dict[str, list[StoredImage]] = {}
        for message in reversed(turns):
            images: list[StoredImage] = []
            for ref in message.images:
                if budget == 0:
                    break
                if uri := uri_of(ref.path):
                    images.append(StoredImage(uri=uri, mime_type=ref.mime_type))
                    budget -= 1
            images_of[message.id] = images
        return [ChatMessage(role=m.role, text=m.text, images=images_of[m.id]) for m in turns]
