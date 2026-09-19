"""Update markers shared by the Firestore-backed modules.

Patches are built as plain dicts with these sentinels; the Firestore stores translate them
to the SDK's own (`DELETE_FIELD`, `SERVER_TIMESTAMP`) and the in-memory test stores resolve
them with a clock.
"""
from typing import Any


class Marker:
    def __init__(self, name: str):
        self.name = name

    def __repr__(self) -> str:
        return f"<{self.name}>"


DELETE = Marker("DELETE")
SERVER_TIME = Marker("SERVER_TIME")


def to_firestore(value: Any) -> Any:
    """Markers → Firestore sentinels, recursively through dicts and lists."""
    from google.cloud import firestore

    if value is DELETE:
        return firestore.DELETE_FIELD
    if value is SERVER_TIME:
        return firestore.SERVER_TIMESTAMP
    if isinstance(value, dict):
        return {k: to_firestore(v) for k, v in value.items()}
    if isinstance(value, list):
        return [to_firestore(v) for v in value]
    return value


def apply_in_memory(target: dict, patch: dict, clock) -> None:
    """Firestore `set(merge=True)` semantics for plain dicts (nested maps merge, DELETE
    removes, SERVER_TIME becomes `clock()`)."""
    for key, value in patch.items():
        if value is DELETE:
            target.pop(key, None)
        elif value is SERVER_TIME:
            target[key] = clock()
        elif isinstance(value, dict):
            child = target.get(key)
            if not isinstance(child, dict):
                child = target[key] = {}
            apply_in_memory(child, value, clock)
        else:
            target[key] = value
