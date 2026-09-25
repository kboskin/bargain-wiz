"""Where the generated lines live: one Firestore document, written only by the schedule,
through the invocation's async client (`core.firestore.FirestoreConnection`)."""

from datetime import UTC, datetime
from typing import Any

from core.utils import Clock

from ..domain.content import Category, GeneratedLines, LinesContent


class FirestoreLinesStore:
    """`content/lines_that_land`, written only by the scheduled generation."""

    def __init__(self, client: Any, clock: Clock):
        self._document = client.collection("content").document("lines_that_land")
        self._clock = clock

    async def read(self) -> LinesContent | None:
        """The stored categories, validated with the same model that produced them: a document
        that does not fit raises, and the service falls back to the bundled lines."""
        snapshot = await self._document.get()
        if not snapshot.exists:
            return None
        data = snapshot.to_dict() or {}
        stored = GeneratedLines.model_validate({"categories": data.get("categories") or []})
        generated_at = data.get("generated_at")
        if not isinstance(generated_at, datetime):
            generated_at = self._clock.now()
        return LinesContent(
            categories=stored.categories,
            updated_at=generated_at.astimezone(UTC),
            source="generated",
        )

    async def write(self, categories: list[Category], *, model: str) -> LinesContent:
        content = LinesContent(
            categories=categories, updated_at=self._clock.now(), source="generated"
        )
        await self._document.set(
            {
                "categories": content.categories_json(),
                "locales": content.locales(),
                "generated_at": content.updated_at,
                "model": model,
            }
        )
        return content
