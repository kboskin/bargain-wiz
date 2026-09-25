"""A model on this machine through Ollama's own `/api/chat`."""

import base64
import json
from typing import Self

import httpx

from core.config import ModelSettings, OllamaSettings
from core.errors import ConfigError, ModelCallFailed
from core.utils import RuntimeEnvironment

from ..provider import ModelProvider
from ..types import Completion, ImagePart, Prompt, TokenUsage


class OllamaProvider(ModelProvider):
    """`ollama/<tag>`, e.g. `ollama/qwen2.5vl:7b` — for the emulator, set in `.env.local`.

    Two things Gemini does that Ollama does not, handled so the same prompts work unchanged:
    - Ollama cannot read `gs://`, so it is handed bytes ([reads_storage_uris] is False; the
      manager downloads stored screenshots first).
    - Gemini is shown the response schema, field descriptions included. Ollama's `format` only
      constrains decoding, so the schema is also written into the system prompt.
    Ollama takes one text and a list of images per message, so the texts are joined in order
    and the images travel alongside them.
    """

    name = "ollama"
    reads_storage_uris = False

    def __init__(self, model: str, settings: ModelSettings, *, ollama: OllamaSettings):
        super().__init__(model, settings)
        self._ollama = ollama

    @classmethod
    def create(cls, model: str, settings: ModelSettings, runtime: RuntimeEnvironment) -> Self:
        return cls(model, settings, ollama=OllamaSettings.current())

    @property
    def url(self) -> str:
        return f"{self._ollama.url}/api/chat"

    async def complete(self, prompt: Prompt, schema: dict) -> Completion:
        reply = await self._post(self.request(prompt, schema))
        text = (reply.get("message") or {}).get("content") or ""
        return Completion(text=text, usage=self.usage(reply))

    @staticmethod
    def usage(reply: dict) -> TokenUsage | None:
        """The counts `/api/chat` reports, or None when it reports neither."""
        if "prompt_eval_count" not in reply and "eval_count" not in reply:
            return None
        return TokenUsage(
            prompt_tokens=int(reply.get("prompt_eval_count") or 0),
            output_tokens=int(reply.get("eval_count") or 0),
        )

    def request(self, prompt: Prompt, schema: dict) -> dict:
        """The `/api/chat` body for one call."""
        user: dict = {"role": "user", "content": "\n\n".join(prompt.texts)}
        if images := [self._base64(image) for image in prompt.images]:
            user["images"] = images
        options: dict = {
            "num_ctx": self._ollama.context_tokens,
            "num_predict": self.settings.max_output_tokens,
        }
        if self.settings.temperature is not None:
            options["temperature"] = self.settings.temperature
        system = f"{prompt.system}\n\nAnswer with JSON only, matching this JSON schema:\n{json.dumps(schema)}"
        return {
            "model": self.model,
            "messages": [{"role": "system", "content": system}, user],
            "format": schema,
            "stream": False,
            "options": options,
        }

    @staticmethod
    def _base64(image: ImagePart) -> str:
        if image.data is None:
            raise ConfigError(
                "Ollama cannot read gs:// images; the manager should have inlined this one"
            )
        return base64.b64encode(image.data).decode()

    async def _post(self, body: dict) -> dict:
        """One HTTP call on a client of its own: a client kept across calls would outlive the
        invocation's event loop."""
        try:
            async with httpx.AsyncClient(timeout=self.settings.timeout_sec) as http:
                response = await http.post(
                    self.url, content=json.dumps(body), headers={"Content-Type": "application/json"}
                )
                response.raise_for_status()
                return response.json()
        except httpx.HTTPStatusError as exc:
            status = exc.response.status_code
            detail = exc.response.text.strip()[:300]
            hint = f"; run `ollama pull {self.model}`" if status == 404 else ""
            raise ModelCallFailed(f"Ollama call failed: HTTP {status} {detail}{hint}") from exc
        except (httpx.HTTPError, ValueError) as exc:
            reason = str(exc) or type(exc).__name__
            raise ModelCallFailed(f"Ollama at {self._ollama.url} did not answer: {reason}") from exc
