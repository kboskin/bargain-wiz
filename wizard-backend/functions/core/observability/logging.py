"""Structured logs: one JSON object per line on Cloud Functions, readable text in the emulator.

Cloud Functions (2nd gen) hands stdout to Cloud Logging, which parses a JSON line into a
structured entry: `severity` and `message` become the entry's own,
`logging.googleapis.com/trace` groups it under its request, and every other key lands in
`jsonPayload`, where log filters and log-based metrics can use it.

Classes get a [StructuredLogger] from the invocation's `Telemetry` and pass facts as keywords
instead of formatting them into the message, so they stay queryable:

    self._log.info("turn queued", uid=uid, cid=cid, images=2)
"""

import json
import logging
import sys
from typing import Any, ClassVar, Self

from core.utils import RuntimeEnvironment


class StructuredLogger(logging.LoggerAdapter):
    """A stdlib logger whose keyword arguments, and the fields it was bound with, become
    fields of the entry."""

    FIELDS: ClassVar[str] = "fields"  # the LogRecord attribute the fields travel in
    PASSED_THROUGH: ClassVar[frozenset[str]] = frozenset(
        {"exc_info", "stack_info", "stacklevel", "extra"}
    )

    def __init__(self, logger: logging.Logger, bound: dict[str, Any] | None = None):
        super().__init__(logger, bound or {})

    @classmethod
    def named(cls, name: str, **bound: Any) -> Self:
        return cls(logging.getLogger(name), bound)

    def bind(self, **fields: Any) -> "StructuredLogger":
        return StructuredLogger(self.logger, {**self.extra, **fields})

    def process(self, msg: Any, kwargs: Any) -> tuple[Any, Any]:
        fields = {key: kwargs.pop(key) for key in list(kwargs) if key not in self.PASSED_THROUGH}
        extra = kwargs.setdefault("extra", {})
        extra[self.FIELDS] = {**self.extra, **extra.get(self.FIELDS, {}), **fields}
        return msg, kwargs

    @classmethod
    def fields_of(cls, record: logging.LogRecord) -> dict[str, Any]:
        return getattr(record, cls.FIELDS, None) or {}


class CloudLoggingFormatter(logging.Formatter):
    """A LogRecord → the JSON line Cloud Logging reads as a structured entry."""

    def format(self, record: logging.LogRecord) -> str:
        message = record.getMessage()
        if record.exc_info:
            # Error Reporting picks a stack trace up from the message, not from another field.
            message = f"{message}\n{self.formatException(record.exc_info)}"
        entry: dict[str, Any] = {
            "severity": record.levelname,
            "message": message,
            "logger": record.name,
        }
        entry.update(StructuredLogger.fields_of(record))
        return json.dumps(entry, default=str, ensure_ascii=False)


class ConsoleFormatter(logging.Formatter):
    """`INFO conversations: turn queued uid=u1 cid=c1`, for the emulator's terminal. The
    invocation's own fields (function, trace) are left out: the terminal already says which
    function is running."""

    HIDDEN: ClassVar[frozenset[str]] = frozenset({"function", "logging.googleapis.com/trace"})

    def format(self, record: logging.LogRecord) -> str:
        text = f"{record.levelname} {record.name}: {record.getMessage()}"
        fields = {
            k: v for k, v in StructuredLogger.fields_of(record).items() if k not in self.HIDDEN
        }
        if fields:
            text += " " + " ".join(f"{key}={value}" for key, value in fields.items())
        if record.exc_info:
            text += "\n" + self.formatException(record.exc_info)
        return text


class LoggingSetup:
    @staticmethod
    def configure(runtime: RuntimeEnvironment, level: int = logging.INFO) -> None:
        """Route every logger through one stdout handler: JSON in the cloud, text in the
        emulator. Process setup, run once when `main` is imported."""
        handler = logging.StreamHandler(sys.stdout)
        handler.setFormatter(ConsoleFormatter() if runtime.emulator else CloudLoggingFormatter())
        root = logging.getLogger()
        root.handlers[:] = [handler]
        root.setLevel(level)
