"""Metrics for Cloud Monitoring, emitted as structured log entries.

Every measurement is one INFO entry from the `metrics` logger: `jsonPayload.metric` names it and
the other fields are its labels and values. A log-based metric turns those entries into a time
series — for instance a distribution over `jsonPayload.latency_ms` filtered on
`jsonPayload.metric="model_call"` and labelled by `jsonPayload.provider` and
`jsonPayload.outcome`. That needs no client library, no extra IAM role and no API request per
call; the metric definitions to create are listed in wizard-backend/AGENTS.md ("Logs and metrics").

Each metric is a [MetricEvent] subclass, so what it carries is declared, typed and the same on
every call. [Metrics] is the interface callers depend on, so the sink can change without
touching them.
"""

import time
from abc import ABC, abstractmethod
from enum import StrEnum
from typing import ClassVar

from pydantic import BaseModel, ConfigDict

from core.errors import ApiError

from .logging import StructuredLogger


class Outcome(StrEnum):
    """How a measured operation ended. A failure is labelled with its error's own `reason`
    (`call_failed`, `invalid_answer`, `bad_request`, …); [of] picks the label."""

    OK = "ok"
    DROPPED = "dropped"  # nothing left to do (the conversation or message is gone)
    INTERNAL = "internal"  # a bug: not an ApiError

    @classmethod
    def of(cls, exc: BaseException) -> str:
        return exc.reason if isinstance(exc, ApiError) else cls.INTERNAL


class MetricEvent(BaseModel):
    """One measurement. Subclasses name the metric and declare its labels and values."""

    model_config = ConfigDict(frozen=True)

    metric: ClassVar[str]


class ModelCall(MetricEvent):
    """One model call: which model, what it was for, how it went, what it cost."""

    metric = "model_call"

    provider: str
    model: str
    operation: str
    outcome: str
    latency_ms: int
    images: int = 0
    prompt_tokens: int = 0
    cached_tokens: int = 0
    output_tokens: int = 0
    thought_tokens: int = 0


class HttpRequest(MetricEvent):
    """One HTTPS call to a function."""

    metric = "http_request"

    function: str
    method: str
    status: int
    code: str | None = None
    latency_ms: int


class GenerationRun(MetricEvent):
    """One run of the `generate` worker: a wizard reply, an Express answer or three options."""

    metric = "generation"

    kind: str
    action: str
    outcome: str
    attempt: int
    final: bool
    latency_ms: int


class LinesRefresh(MetricEvent):
    """One scheduled regeneration of the Lines tab."""

    metric = "lines_refresh"

    outcome: str
    categories: int = 0
    lines: int = 0
    latency_ms: int


class Metrics(ABC):
    @abstractmethod
    def emit(self, event: MetricEvent) -> None: ...


class LogMetrics(Metrics):
    """The production sink: one structured log entry per event, through a logger bound to the
    invocation (so every metric carries the function and the request's trace)."""

    def __init__(self, log: StructuredLogger):
        self._log = log

    def emit(self, event: MetricEvent) -> None:
        self._log.info(event.metric, metric=event.metric, **event.model_dump())


class Stopwatch:
    """Started on construction; [elapsed_ms] is the wall time since."""

    def __init__(self):
        self._started = time.monotonic()

    @property
    def elapsed_ms(self) -> int:
        return int((time.monotonic() - self._started) * 1000)
