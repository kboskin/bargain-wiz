"""What the tests share: in-memory stand-ins for Firebase, and calling the functions."""

from .doubles import (
    FixedClock,
    InMemoryConversationStore,
    InMemoryLinesStore,
    InMemoryMetrics,
    InMemoryPatch,
    InMemoryProfileStore,
    InMemoryScreenshotStore,
    StaticAuthenticator,
)
from .functions import TEST_RUNTIME, Wiring, call, install

__all__ = [
    "TEST_RUNTIME",
    "FixedClock",
    "InMemoryConversationStore",
    "InMemoryLinesStore",
    "InMemoryMetrics",
    "InMemoryPatch",
    "InMemoryProfileStore",
    "InMemoryScreenshotStore",
    "StaticAuthenticator",
    "Wiring",
    "call",
    "install",
]
