"""Gemini on Vertex AI through the google-genai SDK."""

from typing import Any, Self

from core.config import ModelSettings, VertexSettings
from core.errors import ConfigError, ModelCallFailed
from core.utils import RuntimeEnvironment

from ..provider import ModelProvider
from ..types import Completion, ImagePart, Prompt, TokenUsage


class VertexProvider(ModelProvider):
    """`vertex/<gemini model id>`.

    Vertex reads a `gs://` screenshot itself (a Vertex AI capability; the Gemini Developer API
    has none), with the function's own credentials, so a stored screenshot never passes
    through the function again. Gemini 3's cost settings — thinking level and media resolution
    — come from [VertexSettings] and, like the temperature, are sent only when set, so a model
    that lacks one is never asked for it.
    """

    name = "vertex"
    reads_storage_uris = True

    def __init__(self, model: str, settings: ModelSettings, *, vertex: VertexSettings, client: Any):
        super().__init__(model, settings)
        self._vertex = vertex
        self._client = client

    @classmethod
    def create(cls, model: str, settings: ModelSettings, runtime: RuntimeEnvironment) -> Self:
        genai, types = cls._sdk()
        vertex = VertexSettings.current()
        if not runtime.project_id:
            raise ConfigError("Vertex AI: no Google Cloud project id available")
        try:
            client = genai.Client(
                vertexai=True,
                project=runtime.project_id,
                location=vertex.location,
                http_options=types.HttpOptions(timeout=settings.timeout_sec * 1000),
            )
        except Exception as exc:
            raise ModelCallFailed(f"Vertex AI client could not be created: {exc}") from exc
        return cls(model, settings, vertex=vertex, client=client)

    async def complete(self, prompt: Prompt, schema: dict) -> Completion:
        try:
            response = await self._client.aio.models.generate_content(
                model=self.model,
                contents=self.contents(prompt),
                config=self.generation_config(prompt.system, schema),
            )
        except Exception as exc:
            raise ModelCallFailed(f"Gemini call failed: {exc}") from exc
        return Completion(
            text=response.text or "", usage=self.usage(getattr(response, "usage_metadata", None))
        )

    async def aclose(self) -> None:
        await self._client.aio.aclose()

    @staticmethod
    def _sdk() -> tuple[Any, Any]:
        # Imported on first use: google-genai adds ~0.3 s to a cold start, and the functions
        # that never call Gemini (profile, the Lines GET) should not pay for it.
        from google import genai
        from google.genai import types

        return genai, types

    @classmethod
    def contents(cls, prompt: Prompt) -> list:
        _, types = cls._sdk()
        contents: list = []
        for part in prompt.parts:
            if not isinstance(part, ImagePart):
                contents.append(types.Part.from_text(text=part.text))
            elif part.uri:
                contents.append(types.Part.from_uri(file_uri=part.uri, mime_type=part.mime_type))
            else:
                contents.append(types.Part.from_bytes(data=part.data, mime_type=part.mime_type))
        return contents

    def generation_config(self, system: str, schema: dict):
        """JSON mode against [schema], plus the settings that are set."""
        _, types = self._sdk()
        config = types.GenerateContentConfig(
            system_instruction=system,
            response_mime_type="application/json",
            response_schema=schema,
            max_output_tokens=self.settings.max_output_tokens,
        )
        if self.settings.temperature is not None:
            config.temperature = self.settings.temperature
        if self._vertex.thinking_level:
            config.thinking_config = types.ThinkingConfig(
                thinking_level=types.ThinkingLevel[self._vertex.thinking_level.upper()]
            )
        if self._vertex.media_resolution:
            config.media_resolution = types.MediaResolution[
                f"MEDIA_RESOLUTION_{self._vertex.media_resolution.upper()}"
            ]
        return config

    @staticmethod
    def usage(metadata: Any) -> TokenUsage | None:
        if metadata is None:
            return None

        def count(field: str) -> int:
            return int(getattr(metadata, field, None) or 0)

        return TokenUsage(
            prompt_tokens=count("prompt_token_count"),
            cached_tokens=count("cached_content_token_count"),
            output_tokens=count("candidates_token_count"),
            thought_tokens=count("thoughts_token_count"),
        )
