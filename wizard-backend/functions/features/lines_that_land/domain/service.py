"""Serving the Lines tab, and regenerating it on the `refresh_lines` schedule.

Two classes because the two sides need different things: the public GET only reads the
stored document and must keep working whatever the model configuration says, while the
schedule needs the model and nothing about HTTP.
"""

from core.ai import ModelManager, Prompt, TextPart
from core.config import LinesSettings
from core.observability import LinesRefresh, Outcome, Stopwatch, StructuredLogger, Telemetry
from core.utils import Clock

from .content import Category, GeneratedLines, LinesContent
from .ports import LinesStore


class LinesService:
    """What the tab shows: the generated content when there is some, else the bundled lines."""

    def __init__(self, store: LinesStore, *, clock: Clock, log: StructuredLogger):
        self._store = store
        self._clock = clock
        self._log = log

    async def current(self) -> LinesContent:
        try:
            stored = await self._store.read()
        except Exception as exc:  # noqa: BLE001 - the tab must never fail on a storage hiccup
            self._log.warning(
                "could not read the stored lines; serving the bundled ones", error=str(exc)
            )
            stored = None
        return stored or LinesContent.fallback(self._clock.now())


class _Placeholders(dict):
    """A placeholder nobody fills is left as written: a typo in `.env` shows up in the prompt
    instead of failing the scheduled run."""

    def __missing__(self, key: str) -> str:
        return "{" + key + "}"


class LinesGenerator:
    """One model call → fresh categories, stored for the tab.

    Both prompts are params (`LINES_SYSTEM_PROMPT`, `LINES_TASK_PROMPT`); the task prompt is
    filled in with the same values that build the response schema, so it cannot ask for
    something the schema forbids. [GeneratedLines] is what the answer must come back as, and
    the model manager validates it — nothing here parses."""

    def __init__(
        self,
        store: LinesStore,
        model: ModelManager,
        *,
        settings: LinesSettings,
        telemetry: Telemetry,
    ):
        self._store = store
        self._model = model
        self._settings = settings
        self._metrics = telemetry.metrics
        self._log = telemetry.logger("lines_that_land")

    def task_prompt(self) -> str:
        """`LINES_TASK_PROMPT` with the categories, the line count and the languages filled in."""
        ids = self._settings.category_ids
        return self._settings.task_prompt.format_map(
            _Placeholders(
                categories=", ".join(ids),
                count=len(ids),
                lines_per_category=self._settings.per_category,
                locales=", ".join(self._settings.locales),
            )
        )

    def prompt(self) -> Prompt:
        return Prompt(
            system=self._settings.system_prompt, parts=[TextPart(text=self.task_prompt())]
        )

    async def generate(self) -> list[Category]:
        generated = await self._model.generate(self.prompt(), GeneratedLines, operation="lines")
        return generated.answer.categories

    async def refresh(self) -> LinesContent:
        """Generate and store. A failure leaves the previous content in place; the next
        scheduled run tries again."""
        watch = Stopwatch()
        try:
            content = await self._store.write(await self.generate(), model=self._model.model)
        except Exception as exc:
            self._metrics.emit(LinesRefresh(outcome=Outcome.of(exc), latency_ms=watch.elapsed_ms))
            raise
        lines = sum(len(category.tips) for category in content.categories)
        self._metrics.emit(
            LinesRefresh(
                outcome=Outcome.OK,
                categories=len(content.categories),
                lines=lines,
                latency_ms=watch.elapsed_ms,
            )
        )
        self._log.info("lines regenerated", categories=len(content.categories), lines=lines)
        return content
