"""The contract every model API implements."""

from abc import ABC, abstractmethod
from typing import ClassVar, Self

from core.config import ModelSettings
from core.utils import RuntimeEnvironment

from .types import Completion, Prompt


class ModelProvider(ABC):
    """One model API behind the [ModelManager].

    A provider does transport only: it turns a [Prompt] and a JSON schema into its API's
    request and returns the answer's text with the token counts. Validating the answer,
    measuring the call and mapping failures to [UpstreamError]s belong to the manager, so they
    are the same for every provider.

    Adding one: subclass, set [name] (what AI_MODEL says before the slash), implement
    [create] and [complete], and add the class to `ProviderRegistry.default()`.
    """

    name: ClassVar[str]
    # True when the API fetches `gs://` images itself; otherwise the manager inlines the bytes.
    reads_storage_uris: ClassVar[bool] = False

    def __init__(self, model: str, settings: ModelSettings):
        self.model = model
        self.settings = settings

    @classmethod
    def create(cls, model: str, settings: ModelSettings, runtime: RuntimeEnvironment) -> Self:
        """The provider for [model]. Override to read the provider's own settings or build its
        client; this runs once per invocation, never at import."""
        return cls(model, settings)

    @abstractmethod
    async def complete(self, prompt: Prompt, schema: dict) -> Completion:
        """One call whose answer is constrained to [schema]. Raises [ModelCallFailed] when the
        call itself fails; otherwise returns whatever text came back, fitting or not."""

    async def aclose(self) -> None:
        """Release what [create] opened. The invocation's event loop ends right after, so a
        client left open would be closed by nobody."""
