"""Where the generated lines live: one Firestore document, written only by the schedule."""
import logging
from datetime import UTC, datetime

from ..domain.content import Category, GeneratedLines, LinesContent, categories_json, locales_of

logger = logging.getLogger("lines_that_land")

class InMemoryLinesStore:
    """Test double."""

    def __init__(self, content: LinesContent | None = None, clock=lambda: datetime.now(UTC)):
        self.content = content
        self._clock = clock

    def read(self) -> LinesContent | None:
        return self.content

    def write(self, categories: list[Category], *, model: str) -> LinesContent:
        self.content = LinesContent(categories=categories, updated_at=self._clock(), source="generated")
        return self.content


class FirestoreLinesStore:
    """`content/lines_that_land`, written only by the scheduled generation."""

    def __init__(self, client=None, clock=lambda: datetime.now(UTC)):
        if client is None:
            from firebase_admin import firestore

            client = firestore.client()
        # One document holds the current content; only the functions write it.
        self._document = client.collection("content").document("lines_that_land")
        self._clock = clock

    def read(self) -> LinesContent | None:
        """The stored categories, validated with the same model that produced them: a document
        that does not fit raises, and [current] falls back to the bundled lines."""
        snapshot = self._document.get()
        if not snapshot.exists:
            return None
        data = snapshot.to_dict() or {}
        stored = GeneratedLines.model_validate({"categories": data.get("categories") or []})
        generated_at = data.get("generated_at")
        if not isinstance(generated_at, datetime):
            generated_at = datetime.now(UTC)
        return LinesContent(
            categories=stored.categories, updated_at=generated_at.astimezone(UTC), source="generated"
        )

    def write(self, categories: list[Category], *, model: str) -> LinesContent:
        generated_at = self._clock()
        self._document.set(
            {
                "categories": categories_json(categories),
                "locales": locales_of(categories),
                "generated_at": generated_at,
                "model": model,
            }
        )
        return LinesContent(categories=categories, updated_at=generated_at, source="generated")
