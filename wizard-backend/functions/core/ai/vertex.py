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


class JsonGenerator(Protocol):
    model: str

    def generate(self, *, system: str, parts: list[dict], response_model: type[Response]) -> Response: ...

    def generate_json(self, *, system: str, parts: list[dict], schema: dict) -> dict: ...


class VertexGenerator:
    """`parts` items: `{"type": "text", "text": str}` or
    `{"type": "image", "mime_type": str, "data": bytes}`."""

    def __init__(self):
        """Client for the configured project / region / model (config.py). Construction is
        cheap; credentials are resolved lazily by google-auth."""
        from google import genai

        project = firebase_project_id()
        if not project:
            raise UpstreamError("Vertex AI: no Google Cloud project id available")
        self.model = config.VERTEX_MODEL.value
        self._temperature = float(config.VERTEX_TEMPERATURE.value)
        self._max_output_tokens = config.VERTEX_MAX_OUTPUT_TOKENS.value
        self._thinking_budget = config.VERTEX_THINKING_BUDGET.value
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
            else:
                contents.append(types.Part.from_bytes(data=part["data"], mime_type=part["mime_type"]))
        generate_config = types.GenerateContentConfig(
            system_instruction=system,
            response_mime_type="application/json",
            response_schema=schema,
            temperature=self._temperature,
            max_output_tokens=self._max_output_tokens,
        )
        if self._thinking_budget >= 0:
            generate_config.thinking_config = types.ThinkingConfig(thinking_budget=self._thinking_budget)
        try:
            return self._client.models.generate_content(model=self.model, contents=contents, config=generate_config)
        except Exception as exc:  # surfaced to the client as 502
            raise UpstreamError(f"Gemini call failed: {exc}") from exc
