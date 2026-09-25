"""Starting the model call: on the `generate` task queue in the cloud, or in this process."""

import asyncio
from collections.abc import Awaitable, Callable

from core.observability import StructuredLogger

from ..domain.models import GenerationTask


class CloudTasksDispatcher:
    """The real one: the `generate` task-queue function, whose `RateLimits` throttle model calls
    across the project and whose `RetryConfig` retries failures.

    The default is the name of that function in `main.py`, which is also its queue name."""

    def __init__(self, function_name: str = "generate"):
        self._function_name = function_name

    async def dispatch(self, task: GenerationTask) -> None:
        # Imported on first use, like the other Admin SDK clients: only a write enqueues.
        from firebase_admin import functions as admin_functions

        # `on_task_dispatched` reads the callable envelope (`body["data"]`), but the Python
        # Admin SDK enqueues whatever it is given verbatim, so wrap it here. The SDK call is
        # synchronous, so it runs on a thread.
        queue = admin_functions.task_queue(self._function_name)
        await asyncio.to_thread(queue.enqueue, {"data": task.model_dump(mode="json")})


class InlineDispatcher:
    """Runs the work in this process instead of queueing it: the emulator without a Cloud
    Tasks host. [run] is the worker's last-attempt entry point.

    There is no queue to retry, so a failure is recorded by the worker rather than raised: the
    caller already has its ids and reads the outcome from Firestore, exactly as in the cloud."""

    def __init__(self, run: Callable[[GenerationTask], Awaitable[None]], log: StructuredLogger):
        self._run = run
        self._log = log

    async def dispatch(self, task: GenerationTask) -> None:
        try:
            await self._run(task)
        except Exception as exc:  # noqa: BLE001 - already recorded on the message
            self._log.warning("inline generation failed", error=str(exc))
