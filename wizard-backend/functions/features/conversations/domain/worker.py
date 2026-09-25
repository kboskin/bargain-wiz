"""The `generate` queue worker: one model call, and the wizard message it completes.

Split in two so each half can be looked at on its own: [GenerationWorker.job] reads the
conversation and builds exactly what will be asked (the typed request the prompt is made
from); [GenerationWorker.run] asks, writes the answer and records the outcome. What a kind
of generation asks and writes is its [Generation] (`generations.py`); the worker only runs
them. Raises on failure so the queue retries; only the last attempt records the failure for
the user, so a transient error never flashes an error in the chat.
"""

import asyncio

from core.config import QueueSettings, RequestLimits
from core.errors import UpstreamError
from core.observability import GenerationRun, Outcome, Stopwatch, Telemetry
from core.utils import Validation

from .documents import ConversationDocuments
from .generations import GenerationJob, Generations
from .history import ChatHistory
from .models import GenerationTask
from .ports import ConversationStore, ScreenshotStore


class GenerationWorker:
    def __init__(
        self,
        store: ConversationStore,
        screenshots: ScreenshotStore,
        generations: Generations,
        *,
        limits: RequestLimits,
        queue: QueueSettings,
        telemetry: Telemetry,
    ):
        self._store = store
        self._screenshots = screenshots
        self._generations = generations
        self._limits = limits
        self._queue = queue
        self._metrics = telemetry.metrics
        self._log = telemetry.logger("conversations")

    async def run(self, payload: dict, *, attempt: int) -> None:
        """One queue delivery; [attempt] counts from 0 (Cloud Tasks' retry count)."""
        task = Validation.parse(GenerationTask, payload)
        final = attempt + 1 >= self._queue.max_attempts
        watch = Stopwatch()
        outcome: str = Outcome.OK
        try:
            job = await self.job(task)
            if job is None:
                outcome = Outcome.DROPPED
                return
            await self._generations.for_task(task).complete(job, watch)
            self._log.info(
                "generated",
                uid=task.uid,
                cid=task.conversation_id,
                action=task.action,
                kind=task.kind,
            )
        except Exception as exc:
            outcome = Outcome.of(exc)
            self._log.warning(
                "generation failed",
                uid=task.uid,
                cid=task.conversation_id,
                attempt=attempt + 1,
                final=final,
                error=str(exc),
            )
            if final:
                code = "UPSTREAM_ERROR" if isinstance(exc, UpstreamError) else "INTERNAL"
                await self._generations.for_task(task).fail(
                    task, ConversationDocuments.failure(code)
                )
            raise
        finally:
            self._metrics.emit(
                GenerationRun(
                    kind=task.kind,
                    action=task.action,
                    outcome=outcome,
                    attempt=attempt + 1,
                    final=final,
                    latency_ms=watch.elapsed_ms,
                )
            )

    async def run_last_attempt(self, task: GenerationTask) -> None:
        """For the inline dispatcher: there is no queue to retry, so this is the last attempt."""
        await self.run(task.model_dump(mode="json"), attempt=self._queue.max_attempts - 1)

    async def job(self, task: GenerationTask) -> GenerationJob | None:
        """What [run] will ask for [task], or None when the conversation or the message is gone
        (archived and cleared, or a stale redelivery): nothing to complete, nothing to retry."""
        uid, cid, mid = task.uid, task.conversation_id, task.message_id
        # Both reads go out together; the messages are simply unused when the conversation is gone.
        conversation, messages = await asyncio.gather(
            self._store.get_conversation(uid, cid), self._store.list_messages(uid, cid)
        )
        if conversation is None:
            self._log.warning("generation for a deleted conversation", uid=uid, cid=cid)
            return None
        history = ChatHistory(messages)
        target = history.find(mid)
        if target is None:
            self._log.warning("generation for a missing message", uid=uid, cid=cid, mid=mid)
            return None
        turns = history.turns_for(target, include_target=task.action == "options")
        chat = ChatHistory.as_chat(
            turns, uri_of=self._screenshots.uri, max_images=self._limits.max_images
        )
        request = self._generations.for_task(task).request(task, chat, target)
        return GenerationJob(task=task, target=target, turns=turns, request=request)
