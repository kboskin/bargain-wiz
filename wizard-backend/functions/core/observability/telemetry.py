"""What one invocation reports through."""

from .invocation import Invocation
from .logging import StructuredLogger
from .metrics import LogMetrics, Metrics


class Telemetry:
    """The invocation's loggers and metrics, all tagged with the invocation. Made once per
    invocation by the container and handed to every class that logs or measures, so nothing
    reaches for a module-level logger or a context variable."""

    def __init__(self, invocation: Invocation, metrics: Metrics | None = None):
        self.invocation = invocation
        self.metrics = metrics or LogMetrics(self.logger("metrics"))

    def logger(self, name: str) -> StructuredLogger:
        return StructuredLogger.named(name, **self.invocation.log_fields())
