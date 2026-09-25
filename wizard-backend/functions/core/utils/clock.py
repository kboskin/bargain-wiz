"""Time, as something a class is given rather than reads."""

from datetime import UTC, datetime
from typing import Protocol


class Clock(Protocol):
    def now(self) -> datetime:
        """The current time, timezone-aware."""


class SystemClock:
    def now(self) -> datetime:
        return datetime.now(UTC)
