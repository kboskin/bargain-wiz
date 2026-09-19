"""Starting the model call: on the `generate` task queue in the cloud, or in this process."""
import logging

from core import config

from ..domain.models import GenerationTask

logger = logging.getLogger("conversations")


class CloudTasksDispatcher:
    """The real one: the `generate` task-queue function, whose `RateLimits` throttle Gemini
    across the project and whose `RetryConfig` retries failures.

    The default is the name of that function in `main.py`, which is also its queue name."""

    def __init__(self, function_name: str = "generate"):
        self._function_name = function_name

    def dispatch(self, task: GenerationTask) -> None:
        from firebase_admin import functions as admin_functions

        # `on_task_dispatched` reads the callable envelope (`body["data"]`), but the Python
        # Admin SDK enqueues whatever it is given verbatim, so wrap it here.
        admin_functions.task_queue(self._function_name).enqueue({"data": task.model_dump(mode="json")})


class InlineDispatcher:
    """Runs the work in this process instead of queueing it: the emulator without a Cloud
    Tasks host, and tests. [service] is a callable so it can build the worker on demand.

    There is no queue to retry, so this is the last attempt by definition, and a failure is
    recorded rather than raised: the caller already has its ids and reads the outcome from
    Firestore, exactly as it would in the cloud."""

    def __init__(self, service):
        self._service = service

    def dispatch(self, task: GenerationTask) -> None:
        try:
            self._service().generate(task.model_dump(mode="json"), attempt=config.QUEUE_MAX_ATTEMPTS.value - 1)
        except Exception as exc:  # noqa: BLE001 - already recorded on the message
            logger.warning("inline generation failed: %s", exc)
