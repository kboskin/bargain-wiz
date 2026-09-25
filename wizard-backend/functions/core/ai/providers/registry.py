"""Which provider class answers for which AI_MODEL prefix."""

from collections.abc import Iterable
from typing import Self

from core.errors import ConfigError

from ..provider import ModelProvider
from .ollama import OllamaProvider
from .vertex import VertexProvider


class ProviderRegistry:
    def __init__(self, providers: Iterable[type[ModelProvider]]):
        self._providers = {provider.name: provider for provider in providers}

    @classmethod
    def default(cls) -> Self:
        """Every provider this codebase ships."""
        return cls((VertexProvider, OllamaProvider))

    @property
    def names(self) -> list[str]:
        return sorted(self._providers)

    def get(self, name: str) -> type[ModelProvider]:
        provider = self._providers.get(name)
        if provider is None:
            raise ConfigError(
                f"unknown model provider {name!r}; use one of {', '.join(self.names)}"
            )
        return provider
