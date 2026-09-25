"""The model manager: the one way the functions talk to a model."""

from pydantic import BaseModel, ValidationError

from core.config import ModelSettings
from core.errors import ApiError, ConfigError, InvalidModelAnswer, ModelCallFailed
from core.observability import Metrics, ModelCall, Outcome, Stopwatch
from core.storage.cloud import BlobReader
from core.utils import RuntimeEnvironment, Validation

from .images import StoredImageInliner
from .provider import ModelProvider
from .providers import ProviderRegistry
from .types import Generated, Prompt, TokenUsage


class ModelManager:
    """Loads the provider AI_MODEL names and runs every call through the same steps:

    1. stored screenshots are inlined ([StoredImageInliner]) for a provider that cannot read
       `gs://` itself;
    2. the answer is constrained to the response model's JSON schema and validated against it,
       so the caller gets a typed instance or an [UpstreamError], never a dict to pick apart;
    3. anything the provider raises that is not already an [UpstreamError] becomes one;
    4. one `model_call` metric per call: provider, model, operation, outcome, latency, tokens.
    """

    def __init__(self, provider: ModelProvider, *, metrics: Metrics, images: StoredImageInliner):
        self._provider = provider
        self._metrics = metrics
        self._images = images

    @classmethod
    def from_settings(
        cls,
        settings: ModelSettings,
        runtime: RuntimeEnvironment,
        *,
        metrics: Metrics,
        blobs: BlobReader | None = None,
        registry: ProviderRegistry | None = None,
    ) -> "ModelManager":
        """The manager for the model [settings] names, built through [registry] (every shipped
        provider by default)."""
        try:
            provider_cls = (registry or ProviderRegistry.default()).get(settings.spec.provider)
        except ConfigError as exc:
            raise ConfigError(f"AI_MODEL={settings.spec}: {exc}") from exc
        provider = provider_cls.create(settings.spec.name, settings, runtime)
        return cls(provider, metrics=metrics, images=StoredImageInliner(blobs))

    @property
    def provider(self) -> str:
        return self._provider.name

    @property
    def model(self) -> str:
        """The provider's model id — what the documents and responses record as `model`."""
        return self._provider.model

    async def generate[Answer: BaseModel](
        self, prompt: Prompt, response_model: type[Answer], *, operation: str
    ) -> Generated[Answer]:
        """One call constrained to [response_model] → a validated instance of it, with the model
        and the token usage. [operation] says what the call is for (`express`, `reply`, …) and
        labels its metric."""
        watch = Stopwatch()
        usage: TokenUsage | None = None
        outcome: str = Outcome.OK
        try:
            sent = (
                prompt if self._provider.reads_storage_uris else await self._images.inline(prompt)
            )
            completion = await self._provider.complete(sent, response_model.model_json_schema())
            usage = completion.usage
            answer = self.parse(completion.text, response_model)
            return Generated[response_model](answer=answer, model=self.model, usage=usage)
        except ApiError as exc:
            outcome = exc.reason
            raise
        except Exception as exc:  # an SDK or storage error the provider did not map
            outcome = ModelCallFailed.reason
            raise ModelCallFailed(f"{self.provider} call failed: {exc}") from exc
        finally:
            self._metrics.emit(
                ModelCall(
                    provider=self.provider,
                    model=self.model,
                    operation=operation,
                    outcome=outcome,
                    latency_ms=watch.elapsed_ms,
                    images=len(prompt.images),
                    **(usage or TokenUsage()).model_dump(),
                )
            )

    async def aclose(self) -> None:
        await self._provider.aclose()

    def parse[Answer: BaseModel](self, text: str, response_model: type[Answer]) -> Answer:
        """The answer's text → [response_model], or an [InvalidModelAnswer] saying why not."""
        if not text.strip():
            raise InvalidModelAnswer(f"{self.provider} returned an empty answer")
        try:
            return response_model.model_validate_json(text)
        except ValidationError as exc:
            raise InvalidModelAnswer(
                f"{self.provider} answer does not fit {response_model.__name__} ({Validation.describe(exc, 3)})"
            ) from exc
