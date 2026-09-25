"""The conversations feature, wired for one invocation."""

from functools import cached_property

from core.config import ConversationSettings, QueueSettings
from core.services import CoreServices
from core.storage.images import ImageProcessor
from features.negotiation.module import NegotiationModule

from .data.dispatchers import CloudTasksDispatcher, InlineDispatcher
from .data.screenshots import CloudScreenshotStore
from .data.store import FirestoreConversationStore
from .domain.documents import Summaries
from .domain.generations import Generations
from .domain.ports import ConversationStore, Dispatcher, ScreenshotStore
from .domain.screenshots import Screenshots
from .domain.service import ConversationService
from .domain.worker import GenerationWorker
from .presentation.controller import ConversationsController


class ConversationsModule:
    """[store], [screenshots] and [dispatcher] can be handed in (the tests do); by default they
    are Firestore, the bucket, and the queue — or the worker inline, in the emulator without a
    Cloud Tasks emulator ([inline_generation] forces either way)."""

    def __init__(
        self,
        core: CoreServices,
        negotiation: NegotiationModule,
        *,
        store: ConversationStore | None = None,
        screenshots: ScreenshotStore | None = None,
        dispatcher: Dispatcher | None = None,
        inline_generation: bool | None = None,
    ):
        self._core = core
        self._negotiation = negotiation
        self._store = store
        self._screenshots = screenshots
        self._dispatcher = dispatcher
        self._inline_generation = inline_generation

    @cached_property
    def settings(self) -> ConversationSettings:
        return ConversationSettings.current()

    @cached_property
    def queue_settings(self) -> QueueSettings:
        return QueueSettings.current()

    @cached_property
    def store(self) -> ConversationStore:
        return self._store or FirestoreConversationStore(self._core.firestore.client)

    @cached_property
    def screenshots(self) -> ScreenshotStore:
        return self._screenshots or CloudScreenshotStore(self._core.storage)

    @cached_property
    def summaries(self) -> Summaries:
        return Summaries(self.settings)

    @cached_property
    def dispatcher(self) -> Dispatcher:
        if self._dispatcher is not None:
            return self._dispatcher
        inline = (
            self._core.runtime.queues_inline
            if self._inline_generation is None
            else self._inline_generation
        )
        if inline:
            return InlineDispatcher(
                lambda task: self.worker.run_last_attempt(task), self._core.logger("conversations")
            )
        return CloudTasksDispatcher()

    @cached_property
    def service(self) -> ConversationService:
        return ConversationService(
            self.store,
            self.dispatcher,
            screenshots=Screenshots(self.screenshots, ImageProcessor(self._core.image_settings)),
            prompts=self._negotiation.prompts,
            summaries=self.summaries,
            settings=self.settings,
            log=self._core.logger("conversations"),
        )

    @cached_property
    def generations(self) -> Generations:
        return Generations(self.store, self._negotiation.service, self.summaries)

    @cached_property
    def worker(self) -> GenerationWorker:
        return GenerationWorker(
            self.store,
            self.screenshots,
            self.generations,
            limits=self._core.limits,
            queue=self.queue_settings,
            telemetry=self._core.telemetry,
        )

    @cached_property
    def controller(self) -> ConversationsController:
        return ConversationsController(self.service, self._core.authenticator)
