"""What every feature module may use from core, for one invocation."""

from functools import cached_property

from core.ai import ModelManager
from core.auth.firebase import Authenticator, FirebaseAuthenticator
from core.config import ImageSettings, ModelSettings, RequestLimits, SecuritySettings
from core.firestore import FirestoreConnection
from core.http.endpoint import JsonEndpoint
from core.observability import Invocation, Metrics, StructuredLogger, Telemetry
from core.storage.cloud import BlobReader, CloudStorage
from core.utils import Clock, RuntimeEnvironment, SystemClock


class CoreServices:
    """The shared half of the composition root: the runtime, the clock, telemetry, identity,
    Firestore, the bucket and the model, each built on first use and dropped with the
    invocation.

    The parts that reach outside the process can be handed in (for tests); everything else is
    built from the environment. Feature modules (`features/<name>/module.py`) take this and
    build their own services on top of it."""

    def __init__(
        self,
        invocation: Invocation,
        *,
        runtime: RuntimeEnvironment | None = None,
        clock: Clock | None = None,
        metrics: Metrics | None = None,
        authenticator: Authenticator | None = None,
        blobs: BlobReader | None = None,
    ):
        self._invocation = invocation
        self._runtime = runtime
        self._clock = clock
        self._metrics = metrics
        self._authenticator = authenticator
        self._blobs = blobs

    # -- settings shared by several features ------------------------------------

    @cached_property
    def model_settings(self) -> ModelSettings:
        return ModelSettings.current()

    @cached_property
    def limits(self) -> RequestLimits:
        return RequestLimits.current()

    @cached_property
    def image_settings(self) -> ImageSettings:
        return ImageSettings.current()

    @cached_property
    def security_settings(self) -> SecuritySettings:
        return SecuritySettings.current()

    # -- services ----------------------------------------------------------------

    @cached_property
    def runtime(self) -> RuntimeEnvironment:
        return self._runtime or RuntimeEnvironment.current()

    @cached_property
    def clock(self) -> Clock:
        return self._clock or SystemClock()

    @cached_property
    def telemetry(self) -> Telemetry:
        return Telemetry(self._invocation, self._metrics)

    def logger(self, name: str) -> StructuredLogger:
        return self.telemetry.logger(name)

    @cached_property
    def authenticator(self) -> Authenticator:
        return self._authenticator or FirebaseAuthenticator(self.security_settings)

    @cached_property
    def firestore(self) -> FirestoreConnection:
        """This invocation's Firestore client, for the feature stores that need one."""
        return FirestoreConnection()

    @cached_property
    def storage(self) -> CloudStorage:
        return CloudStorage(self.image_settings.bucket)

    @cached_property
    def model(self) -> ModelManager:
        """The model AI_MODEL names. A stored screenshot is read through [blobs] (the bucket by
        default) when the provider cannot fetch it itself."""
        return ModelManager.from_settings(
            self.model_settings,
            self.runtime,
            metrics=self.telemetry.metrics,
            blobs=self._blobs or self.storage,
        )

    def endpoint(self, *methods: str) -> JsonEndpoint:
        return JsonEndpoint(methods, self.telemetry)

    async def aclose(self) -> None:
        """Close what this invocation opened (the model and Firestore clients), before its
        event loop ends."""
        try:
            if "model" in self.__dict__:
                await self.model.aclose()
        finally:
            if "firestore" in self.__dict__:
                await self.firestore.aclose()
