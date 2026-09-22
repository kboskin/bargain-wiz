"""Gemini on Vertex AI through the google-genai SDK.

The functions only need "system prompt + parts → an answer that fits a schema", so that is the
whole surface here and tests can substitute a fake generator.

Prefer [VertexGenerator.generate]: the schema is a pydantic model, google-genai sends it as the
response schema and validates the reply against it, so the caller gets a typed object instead of
a dict to pick apart. [VertexGenerator.generate_json] is the same call with a hand-written JSON
schema, for the negotiation endpoints that still use one.
"""
import json
import logging
from typing import Any, Protocol, TypeVar

from pydantic import BaseModel, ValidationError

from core import config
from core.errors import UpstreamError
from core.runtime import firebase_project_id

logger = logging.getLogger("vertex")

Response = TypeVar("Response", bound=BaseModel)

THINKING_LEVELS = ("low", "medium", "high")
MEDIA_RESOLUTIONS = ("low", "medium", "high")


def _optional_choice(name: str, raw: str, allowed: tuple[str, ...]) -> str | None:
    """A config choice: empty means "do not send"; anything else must be one of [allowed]."""
    value = (raw or "").strip().lower()
    if not value:
        return None
    if value not in allowed:
        raise UpstreamError(f"{name} must be one of {', '.join(allowed)} (got {raw!r})")
    return value


def _optional_float(name: str, raw: str) -> float | None:
    value = (raw or "").strip()
    if not value:
        return None
    try:
        return float(value)
    except ValueError as exc:
        raise UpstreamError(f"{name} must be a number (got {raw!r})") from exc


def log_usage(model: str, usage: Any) -> None:
    """One INFO line per model call with the token counts that make up the bill: prompt,
    cached prefix (implicit caching, billed at a fraction), visible output and thinking
    (both billed as output). Cloud Logging turns these into a cost dashboard."""
    if usage is None:
        return

    def count(field: str) -> int:
        return int(getattr(usage, field, None) or 0)

    logger.info(
        "gemini usage model=%s prompt_tokens=%d cached_tokens=%d output_tokens=%d thought_tokens=%d total_tokens=%d",
        model,
        count("prompt_token_count"),
        count("cached_content_token_count"),
        count("candidates_token_count"),
        count("thoughts_token_count"),
        count("total_token_count"),
    )


class JsonGenerator(Protocol):
    model: str

    def generate(self, *, system: str, parts: list[dict], response_model: type[Response]) -> Response: ...

    def generate_json(self, *, system: str, parts: list[dict], schema: dict) -> dict: ...


class VertexGenerator:
    """`parts` items: `{"type": "text", "text": str}`, or an image as either
    `{"type": "image", "mime_type": str, "data": bytes}` (bytes this request carried) or
    `{"type": "image", "mime_type": str, "uri": "gs://…"}` (already in Cloud Storage —
    Vertex fetches it, which is why it never travels through here twice)."""

    def __init__(self):
        """Client for the configured project / region / model (config.py). Construction is
        cheap; credentials are resolved lazily by google-auth."""
        from google import genai

        project = firebase_project_id()
        if not project:
            raise UpstreamError("Vertex AI: no Google Cloud project id available")
        self.model = config.VERTEX_MODEL.value
        self._temperature = _optional_float("VERTEX_TEMPERATURE", config.VERTEX_TEMPERATURE.value)
        self._max_output_tokens = config.VERTEX_MAX_OUTPUT_TOKENS.value
        self._thinking_level = _optional_choice("VERTEX_THINKING_LEVEL", config.VERTEX_THINKING_LEVEL.value, THINKING_LEVELS)
        self._media_resolution = _optional_choice(
            "VERTEX_MEDIA_RESOLUTION", config.VERTEX_MEDIA_RESOLUTION.value, MEDIA_RESOLUTIONS
        )
        try:
            self._client = genai.Client(vertexai=True, project=project, location=config.VERTEX_LOCATION.value)
        except Exception as exc:
            raise UpstreamError(f"Vertex AI client could not be created: {exc}") from exc

    def generate(self, *, system: str, parts: list[dict], response_model: type[Response]) -> Response:
        """One call constrained to [response_model] → a validated instance of it. Field types,
        `Literal` choices and `Field(description=…)` all reach the model as the response schema,
        so what the model may answer and what the caller gets are the same declaration."""
        response = self._respond(system=system, parts=parts, schema=response_model)
        if isinstance(response.parsed, response_model):
            return response.parsed
        # google-genai leaves `parsed` empty when the answer does not fit the model; validate it
        # here to report why rather than "empty response".
        if not response.text:
            raise UpstreamError("Gemini returned an empty response")
        try:
            return response_model.model_validate_json(response.text)
        except ValidationError as exc:
            problems = "; ".join(f"{'.'.join(str(p) for p in e['loc'])}: {e['msg']}" for e in exc.errors()[:3])
            raise UpstreamError(f"Gemini answer does not fit {response_model.__name__} ({problems})") from exc

    def generate_json(self, *, system: str, parts: list[dict], schema: dict) -> dict:
        """One call constrained to a hand-written JSON schema → the decoded object."""
        response = self._respond(system=system, parts=parts, schema=schema)
        if not response.text:
            raise UpstreamError("Gemini returned an empty response")
        try:
            data = json.loads(response.text)
        except ValueError as exc:
            raise UpstreamError("Gemini returned invalid JSON") from exc
        if not isinstance(data, dict):
            raise UpstreamError("Gemini returned a non-object JSON value")
        return data

    def _respond(self, *, system: str, parts: list[dict], schema: Any):
        """The call itself: JSON mode against [schema] (a pydantic model or a JSON schema dict)."""
        from google.genai import types

        contents: list[Any] = []
        for part in parts:
            if part["type"] == "text":
                contents.append(types.Part.from_text(text=part["text"]))
            elif part.get("uri"):
                # gs:// is a Vertex AI capability (the Developer API has no such thing); the
                # bucket is read with this function's own credentials.
                contents.append(types.Part.from_uri(file_uri=part["uri"], mime_type=part["mime_type"]))
            else:
                contents.append(types.Part.from_bytes(data=part["data"], mime_type=part["mime_type"]))
        generate_config = self._generation_config(system=system, schema=schema)
        try:
            response = self._client.models.generate_content(model=self.model, contents=contents, config=generate_config)
        except Exception as exc:  # surfaced to the client as 502
            raise UpstreamError(f"Gemini call failed: {exc}") from exc
        log_usage(self.model, getattr(response, "usage_metadata", None))
        return response

    def _generation_config(self, *, system: str, schema: Any):
        """JSON mode against [schema] plus the cost settings: thinking level, media resolution
        and temperature are sent only when configured, so a model that lacks one is not
        asked for it."""
        from google.genai import types

        generate_config = types.GenerateContentConfig(
            system_instruction=system,
            response_mime_type="application/json",
            response_schema=schema,
            max_output_tokens=self._max_output_tokens,
        )
        if self._temperature is not None:
            generate_config.temperature = self._temperature
        if self._thinking_level:
            generate_config.thinking_config = types.ThinkingConfig(
                thinking_level=types.ThinkingLevel[self._thinking_level.upper()]
            )
        if self._media_resolution:
            generate_config.media_resolution = types.MediaResolution[f"MEDIA_RESOLUTION_{self._media_resolution.upper()}"]
        return generate_config
