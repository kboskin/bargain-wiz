"""Firestore values → what an endpoint may put in a JSON body."""
from datetime import UTC, datetime
from typing import Any


def jsonable(value: Any) -> Any:
    """Firestore returns datetimes; the API speaks ISO-8601."""
    if isinstance(value, dict):
        return {k: jsonable(v) for k, v in value.items()}
    if isinstance(value, list):
        return [jsonable(v) for v in value]
    if isinstance(value, datetime):
        return value.astimezone(UTC).isoformat(timespec="seconds").replace("+00:00", "Z")
    return value

