"""The Lines tab feature, wired for one invocation."""

from functools import cached_property

from core.config import LinesSettings
from core.services import CoreServices

from .data.store import FirestoreLinesStore
from .domain.ports import LinesStore
from .domain.service import LinesGenerator, LinesService
from .presentation.controller import LinesController


class LinesModule:
    """The public GET needs only [service] and [controller]; the schedule needs [generator],
    the one part that builds a model."""

    def __init__(self, core: CoreServices, *, store: LinesStore | None = None):
        self._core = core
        self._store = store

    @cached_property
    def settings(self) -> LinesSettings:
        return LinesSettings.current()

    @cached_property
    def store(self) -> LinesStore:
        return self._store or FirestoreLinesStore(self._core.firestore.client, self._core.clock)

    @cached_property
    def service(self) -> LinesService:
        return LinesService(
            self.store, clock=self._core.clock, log=self._core.logger("lines_that_land")
        )

    @cached_property
    def generator(self) -> LinesGenerator:
        return LinesGenerator(
            self.store, self._core.model, settings=self.settings, telemetry=self._core.telemetry
        )

    @cached_property
    def controller(self) -> LinesController:
        return LinesController(self.service, self.settings)
