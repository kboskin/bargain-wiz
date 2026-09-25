"""Firestore values → what may go in a JSON body."""

from datetime import UTC, datetime
from typing import Any


class JsonValue:
    @classmethod
    def of(cls, value: Any) -> Any:
        """Firestore returns datetimes; the API speaks ISO-8601 in UTC with a `Z`."""
        if isinstance(value, dict):
            return {k: cls.of(v) for k, v in value.items()}
        if isinstance(value, list):
            return [cls.of(v) for v in value]
        if isinstance(value, datetime):
            return cls.timestamp(value)
        return value

    @staticmethod
    def timestamp(value: datetime) -> str:
        return value.astimezone(UTC).isoformat(timespec="seconds").replace("+00:00", "Z")
