"""Gemini on Vertex AI through the google-genai SDK.

The functions only need "system prompt + parts → JSON matching a schema"; that is the whole
surface here, so tests can substitute a fake generator.
"""
import json
import logging
from typing import Any, Protocol

import config
from errors import UpstreamError
from runtime import firebase_project_id

logger = logging.getLogger("vertex")



class JsonGenerator(Protocol):
    model: str

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
