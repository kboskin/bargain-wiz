"""The composition root for one invocation: the core services and one module per feature.

`main.py` makes a [Container] per call — [for_request] over HTTP, [for_background] for the
queue and the schedule — and asks a feature module for what it needs: a controller, the
worker, the Lines generator. Every piece is built on first use and dropped with the
invocation, so nothing is shared between requests, and settings are read lazily, section by
section: a bad value only breaks what uses it (a typo in VERTEX_THINKING_LEVEL cannot take
down the public Lines endpoint).

The parts that reach outside the process — stores, the screenshot bucket, the
authenticator, the metrics sink, the dispatcher — can be handed in, which is how the tests
run the real services against in-memory stores. The model is never handed in: it is always
what AI_MODEL names — Vertex in the cloud, a local Ollama model in the emulator and in tests.

Everything below is `async`. Firebase calls each function synchronously, so every entry point
runs one invocation on its own event loop — `asyncio.run(container.serve(...))` — and [serve]
/ [run] close what the invocation opened before that loop ends.
"""

from collections.abc import Awaitable, Callable
from functools import cached_property
from typing import Self

from firebase_functions import https_fn

from core.auth.firebase import Authenticator
from core.http.endpoint import Handler, JsonEndpoint
from core.observability import Invocation, Metrics
from core.services import CoreServices
from core.utils import Clock, RuntimeEnvironment
from features.conversations.domain.ports import ConversationStore, Dispatcher, ScreenshotStore
from features.conversations.module import ConversationsModule
from features.lines_that_land.domain.ports import LinesStore
from features.lines_that_land.module import LinesModule
from features.negotiation.module import NegotiationModule
from features.profile.domain.ports import ProfileStore
from features.profile.module import ProfileModule


class Container:
    def __init__(
        self,
        invocation: Invocation,
        *,
        runtime: RuntimeEnvironment | None = None,
        clock: Clock | None = None,
        metrics: Metrics | None = None,
        authenticator: Authenticator | None = None,
        conversation_store: ConversationStore | None = None,
        screenshot_store: ScreenshotStore | None = None,
        profile_store: ProfileStore | None = None,
        lines_store: LinesStore | None = None,
        dispatcher: Dispatcher | None = None,
        inline_generation: bool | None = None,
    ):
        self.core = CoreServices(
            invocation,
            runtime=runtime,
            clock=clock,
            metrics=metrics,
            authenticator=authenticator,
            # A provider that cannot fetch a stored screenshot reads it where it was stored.
            blobs=screenshot_store,
        )
        self._conversation_store = conversation_store
        self._screenshot_store = screenshot_store
        self._profile_store = profile_store
        self._lines_store = lines_store
        self._dispatcher = dispatcher
        self._inline_generation = inline_generation

    @classmethod
    def for_request(cls, function: str, req: https_fn.Request) -> Self:
        runtime = RuntimeEnvironment.current()
        return cls(
            Invocation.from_request(function, req.headers, runtime.project_id), runtime=runtime
        )

    @classmethod
    def for_background(cls, function: str) -> Self:
        return cls(Invocation.background(function))

    def endpoint(self, *methods: str) -> JsonEndpoint:
        return self.core.endpoint(*methods)

    async def serve(
        self, req: https_fn.Request, methods: tuple[str, ...], route: Callable[[Self], Handler]
    ) -> https_fn.Response:
        """One HTTPS invocation: [route] picks the controller method that answers it. It is
        resolved inside the endpoint, so a misconfiguration becomes a 500 like any failure."""
        try:
            return await self.endpoint(*methods).handle(req, lambda r: route(self)(r))
        finally:
            await self.aclose()

    async def run(self, job: Callable[[Self], Awaitable[None]]) -> None:
        """One background invocation (a queued task, a scheduled run)."""
        try:
            await job(self)
        finally:
            await self.aclose()

    async def aclose(self) -> None:
        await self.core.aclose()

    @cached_property
    def negotiation(self) -> NegotiationModule:
        return NegotiationModule(self.core)

    @cached_property
    def conversations(self) -> ConversationsModule:
        return ConversationsModule(
            self.core,
            self.negotiation,
            store=self._conversation_store,
            screenshots=self._screenshot_store,
            dispatcher=self._dispatcher,
            inline_generation=self._inline_generation,
        )

    @cached_property
    def profile(self) -> ProfileModule:
        return ProfileModule(self.core, store=self._profile_store)

    @cached_property
    def lines(self) -> LinesModule:
        return LinesModule(self.core, store=self._lines_store)
