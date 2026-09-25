"""What the Lines feature needs from storage (implemented in `..data.store`)."""

from typing import Protocol

from .content import Category, LinesContent


class LinesStore(Protocol):
    async def read(self) -> LinesContent | None:
        """The stored content, or None before the first generation."""

    async def write(self, categories: list[Category], *, model: str) -> LinesContent:
        """Replace the stored content and return what a reader would now see."""
