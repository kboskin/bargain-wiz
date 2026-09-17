"""Gemini on Vertex AI through the google-genai SDK.

The functions only need "system prompt + parts → JSON matching a schema"; that is the whole
surface here, so tests can substitute a fake generator.
"""
import json
import logging
from typing import Any, Protocol

from firebase_functions import params

from runtime import firebase_project_id

logger = logging.getLogger("vertex")

VERTEX_LOCATION = params.StringParam(
    "VERTEX_LOCATION", default="us-central1", description="Vertex AI region for Gemini calls."
)
VERTEX_MODEL = params.StringParam(
    "VERTEX_MODEL",
    default="gemini-2.5-flash",
    description="Gemini model id used by the negotiation functions.",
)
VERTEX_THINKING_BUDGET = params.IntParam(
    "VERTEX_THINKING_BUDGET",
    default=0,
    description="Thinking token budget for Gemini 2.5 models (0 = off: fastest and cheapest; "
    "-1 = do not send the setting, for models without thinking).",
)


class UpstreamError(Exception):
    """The model call failed or returned something unusable → 502."""


class JsonGenerator(Protocol):
    model: str

    def generate_json(self, *, system: str, parts: list[dict], schema: dict) -> dict: ...


class VertexGenerator:
    """`parts` items: `{"type": "text", "text": str}` or
    `{"type": "image", "mime_type": str, "data": bytes}`."""

    def __init__(
        self,
        project: str | None = None,
        location: str | None = None,
        model: str | None = None,
        temperature: float = 0.7,
        max_output_tokens: int = 2048,
        thinking_budget: int | None = None,
    ):
        from google import genai

        project = project or firebase_project_id()
        if not project:
            raise UpstreamError("Vertex AI: no Google Cloud project id available")
        self.model = model or VERTEX_MODEL.value
        self._temperature = temperature
        self._max_output_tokens = max_output_tokens
        self._thinking_budget = VERTEX_THINKING_BUDGET.value if thinking_budget is None else thinking_budget
        self._client = genai.Client(vertexai=True, project=project, location=location or VERTEX_LOCATION.value)

    def generate_json(self, *, system: str, parts: list[dict], schema: dict) -> dict:
        from google.genai import types

        contents: list[Any] = []
        for part in parts:
            if part["type"] == "text":
                contents.append(types.Part.from_text(text=part["text"]))
            else:
                contents.append(types.Part.from_bytes(data=part["data"], mime_type=part["mime_type"]))
        config = types.GenerateContentConfig(
            system_instruction=system,
            response_mime_type="application/json",
            response_schema=schema,
            temperature=self._temperature,
            max_output_tokens=self._max_output_tokens,
        )
        if self._thinking_budget >= 0:
            config.thinking_config = types.ThinkingConfig(thinking_budget=self._thinking_budget)
        try:
            response = self._client.models.generate_content(model=self.model, contents=contents, config=config)
            text = response.text
        except Exception as exc:  # surfaced to the client as 502
            raise UpstreamError(f"Gemini call failed: {exc}") from exc
        if not text:
            raise UpstreamError("Gemini returned an empty response")
        try:
            data = json.loads(text)
        except ValueError as exc:
            raise UpstreamError("Gemini returned invalid JSON") from exc
        if not isinstance(data, dict):
            raise UpstreamError("Gemini returned a non-object JSON value")
        return data
