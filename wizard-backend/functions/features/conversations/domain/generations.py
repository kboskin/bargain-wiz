"""The three kinds of generation a queued task can be, one class each.

A task is a Pro reply, an Express answer or three options for a Pro reply. They differ in
exactly three things — what they ask the model, what they write when the answer lands, and
what they write when the last attempt fails — so each kind is a [Generation] that owns those
three, and the worker only ever talks to the abstraction ([Generations.for_task] picks one).
"""

from abc import ABC, abstractmethod

from pydantic import BaseModel, ConfigDict

from core.ai import Generated
from core.errors import BadRequest
from core.firestore import Patch
from core.observability import Stopwatch
from features.negotiation.domain.models import ChatMessage, ExpressRequest, ProRequest
from features.negotiation.domain.service import NegotiationService

from .documents import (
    ConversationPatches,
    ExpressRecord,
    Role,
    StoredConversation,
    StoredMessage,
    Summaries,
)
from .models import GenerationTask
from .ports import ConversationStore


class GenerationJob(BaseModel):
    """One task, resolved against the stored conversation: the message it completes, the
    turns it reads, and the request the prompt is built from."""

    model_config = ConfigDict(frozen=True)

    task: GenerationTask
    target: StoredMessage
    turns: list[StoredMessage]
    request: ExpressRequest | ProRequest


class Generation(ABC):
    """What one kind of generation asks, and what it writes."""

    def __init__(
        self, store: ConversationStore, negotiation: NegotiationService, summaries: Summaries
    ):
        self._store = store
        self._negotiation = negotiation
        self._summaries = summaries

    def request(
        self,
        task: GenerationTask,
        chat: list[ChatMessage],
        target: StoredMessage,
        conversation: StoredConversation,
    ) -> ExpressRequest | ProRequest:
        """The request the prompt is built from; a 400 when the chat holds nothing to answer.
        [target] is the message the generation completes — on a redo it still holds the answer
        being replaced, which the prompt shows so the new one differs. [conversation] holds
        what the chat itself was set up with (a Pro chat's objective)."""
        try:
            return self._request(task, chat, target, conversation)
        except ValueError as exc:
            raise BadRequest(f"nothing to answer yet: {exc}") from exc

    @abstractmethod
    def _request(
        self,
        task: GenerationTask,
        chat: list[ChatMessage],
        target: StoredMessage,
        conversation: StoredConversation,
    ) -> ExpressRequest | ProRequest: ...

    @abstractmethod
    async def complete(self, job: GenerationJob, watch: Stopwatch) -> None:
        """Ask the model and write the answer."""

    @abstractmethod
    async def fail(self, task: GenerationTask, detail: dict) -> None:
        """Write the failure the app shows, after the last attempt."""

    # -- what the turn-completing kinds share --------------------------------------

    async def _answered(
        self,
        task: GenerationTask,
        watch: Stopwatch,
        generated: Generated,
        *,
        message: Patch,
        conversation: Patch,
    ) -> None:
        uid, cid = task.uid, task.conversation_id
        answered = ConversationPatches.answered(
            message, model=generated.model, latency_ms=watch.elapsed_ms, usage=generated.usage
        )
        await self._store.merge_message(uid, cid, task.message_id, answered)
        await self._store.merge_conversation(
            uid, cid, ConversationPatches.turn_finished(conversation)
        )

    async def _turn_failed(self, task: GenerationTask, detail: dict) -> None:
        uid, cid = task.uid, task.conversation_id
        await self._store.merge_message(
            uid, cid, task.message_id, ConversationPatches.answer_failed(detail)
        )
        await self._store.merge_conversation(uid, cid, ConversationPatches.turn_failed(detail))


class ReplyGeneration(Generation):
    """The wizard's reply to the buyer's latest Pro message (or a redo of it)."""

    def _request(
        self,
        task: GenerationTask,
        chat: list[ChatMessage],
        target: StoredMessage,
        conversation: StoredConversation,
    ) -> ProRequest:
        return ProRequest(
            messages=chat,
            mode="reply",
            regenerate=task.regenerate,
            replacing=target.text if task.regenerate else None,
            objective=conversation.objective,
            profile=task.profile,
        )

    async def complete(self, job: GenerationJob, watch: Stopwatch) -> None:
        generated = await self._negotiation.reply(job.request)
        reply = generated.answer.reply
        await self._answered(
            job.task,
            watch,
            generated,
            message={"text": reply},
            conversation={"preview": self._summaries.preview(reply)},
        )

    async def fail(self, task: GenerationTask, detail: dict) -> None:
        await self._turn_failed(task, detail)


class ExpressGeneration(Generation):
    """What the screenshots show and three lines to send, for an Express deal. The answer is
    written on the message and on the conversation, which is where the Express flow reads it."""

    def _request(
        self,
        task: GenerationTask,
        chat: list[ChatMessage],
        target: StoredMessage,
        conversation: StoredConversation,
    ) -> ExpressRequest:
        text = "\n\n".join(m.text for m in chat if m.role == Role.USER and m.text) or None
        images = [image for m in chat for image in m.images]
        return ExpressRequest(
            images=images,
            text=text,
            keyword=task.keyword,
            replacing=target.line_texts if task.regenerate else [],
            objective=conversation.objective,
            profile=task.profile,
        )

    async def complete(self, job: GenerationJob, watch: Stopwatch) -> None:
        generated = await self._negotiation.express(job.request)
        answer = generated.answer
        images = [ref for turn in job.turns for ref in turn.images]
        record = ExpressRecord(
            seeing=answer.seeing, lines=answer.lines, keyword=job.task.keyword, images=images
        )
        await self._answered(
            job.task,
            watch,
            generated,
            message={"text": answer.seeing, "seeing": answer.seeing, "lines": answer.lines},
            conversation={
                "express": record,
                "title": self._summaries.title(seeing=answer.seeing, has_images=bool(images)),
                "preview": self._summaries.preview(answer.lines[0].text),
            },
        )

    async def fail(self, task: GenerationTask, detail: dict) -> None:
        await self._turn_failed(task, detail)


class OptionsGeneration(Generation):
    """Three lines for a Pro reply that is already there: they attach to that message and
    leave the turn alone."""

    def _request(
        self,
        task: GenerationTask,
        chat: list[ChatMessage],
        target: StoredMessage,
        conversation: StoredConversation,
    ) -> ProRequest:
        return ProRequest(
            messages=chat, mode="options", objective=conversation.objective, profile=task.profile
        )

    async def complete(self, job: GenerationJob, watch: Stopwatch) -> None:
        generated = await self._negotiation.options(job.request)
        task = job.task
        await self._store.merge_message(
            task.uid,
            task.conversation_id,
            task.message_id,
            ConversationPatches.options_answered(generated.answer.lines, usage=generated.usage),
        )
        await self._store.merge_conversation(
            task.uid, task.conversation_id, ConversationPatches.touched()
        )

    async def fail(self, task: GenerationTask, detail: dict) -> None:
        await self._store.merge_message(
            task.uid,
            task.conversation_id,
            task.message_id,
            ConversationPatches.options_failed(detail),
        )


class Generations:
    """The kinds of generation, and which one a task is."""

    def __init__(
        self, store: ConversationStore, negotiation: NegotiationService, summaries: Summaries
    ):
        self._reply = ReplyGeneration(store, negotiation, summaries)
        self._express = ExpressGeneration(store, negotiation, summaries)
        self._options = OptionsGeneration(store, negotiation, summaries)

    def for_task(self, task: GenerationTask) -> Generation:
        if task.action == "options":
            return self._options
        return self._express if task.kind == "express" else self._reply
