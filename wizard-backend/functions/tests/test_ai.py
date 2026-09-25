"""The model manager and the providers behind it.

What each provider sends is checked on the request it builds (no network); what comes back is
checked against the local model. Failure paths use the real Ollama provider against a closed
port or a model that is not pulled.
"""

import asyncio
import base64
import io

import pytest
from PIL import Image as PilImage
from pydantic import BaseModel

from core.ai import ImagePart, ModelManager, Prompt, TextPart, TokenUsage
from core.ai.providers import OllamaProvider, VertexProvider
from core.config import ModelSettings, OllamaSettings, VertexSettings
from core.errors import ConfigError, InvalidModelAnswer, ModelCallFailed, UpstreamError
from core.observability import ModelCall
from features.negotiation.domain.answers import ReplyAnswer
from support import TEST_RUNTIME, InMemoryMetrics, InMemoryScreenshotStore


class Answer(BaseModel):
    value: str


def _settings(**overrides) -> ModelSettings:
    return ModelSettings.model_validate(
        {
            "spec": "ollama/qwen2.5vl:7b",
            "max_output_tokens": 256,
            "temperature": None,
            "timeout_sec": 300,
            **overrides,
        }
    )


def _manager(metrics=None, blobs=None) -> ModelManager:
    return ModelManager.from_settings(
        ModelSettings.current(), TEST_RUNTIME, metrics=metrics or InMemoryMetrics(), blobs=blobs
    )


def _jpeg() -> bytes:
    buf = io.BytesIO()
    PilImage.new("RGB", (64, 48), "red").save(buf, format="JPEG")
    return buf.getvalue()


PROMPT = Prompt(system="Be brief.", parts=[TextPart(text="Say hi.")])


def _run_generate(manager, *args, **kwargs):
    return asyncio.run(manager.generate(*args, **kwargs))


# ── the call's parts ──────────────────────────────────────────────────────────


def test_an_image_part_has_exactly_one_source():
    assert ImagePart(mime_type="image/jpeg", data=b"x").data == b"x"
    assert ImagePart(mime_type="image/jpeg", uri="gs://b/o.jpg").uri == "gs://b/o.jpg"
    for neither_or_both in ({}, {"data": b"x", "uri": "gs://b/o.jpg"}):
        with pytest.raises(ValueError):
            ImagePart(mime_type="image/jpeg", **neither_or_both)


# ── validating the answer ─────────────────────────────────────────────────────


def test_an_answer_that_fits_comes_back_typed():
    assert _manager().parse('{"value": "hi"}', Answer) == Answer(value="hi")


@pytest.mark.parametrize("text", ['{"other": 1}', "not json", "  "])
def test_an_answer_that_does_not_fit_is_an_invalid_answer(text):
    with pytest.raises(InvalidModelAnswer) as raised:
        _manager().parse(text, Answer)
    assert raised.value.status == 502 and raised.value.reason == "invalid_answer"
    assert "wizard could not answer" in raised.value.public_message


def test_the_error_names_the_model_and_the_field():
    with pytest.raises(InvalidModelAnswer) as raised:
        _manager().parse('{"other": 1}', Answer)
    assert "Answer" in str(raised.value) and "value" in str(raised.value)


# ── Ollama: the request it builds ─────────────────────────────────────────────


def test_the_ollama_request_carries_the_prompt_the_screenshots_the_schema_and_the_window():
    provider = OllamaProvider(
        "qwen2.5vl:7b",
        _settings(temperature=0.2),
        ollama=OllamaSettings(url="http://127.0.0.1:11434", context_tokens=8192),
    )
    prompt = Prompt(
        system="Be brief.",
        parts=[
            ImagePart(mime_type="image/jpeg", data=b"first"),
            TextPart(text="Material: screenshots."),
            ImagePart(mime_type="image/png", data=b"second"),
            TextPart(text="Task: three lines."),
        ],
    )
    schema = Answer.model_json_schema()

    body = provider.request(prompt, schema)

    assert body["model"] == "qwen2.5vl:7b" and body["stream"] is False and body["format"] == schema
    assert body["options"] == {"num_ctx": 8192, "num_predict": 256, "temperature": 0.2}
    system, user = body["messages"]
    assert system["role"] == "system" and system["content"].startswith("Be brief.")
    assert '"value"' in system["content"]  # the schema is shown to the model, not only enforced
    assert user == {
        "role": "user",
        "content": "Material: screenshots.\n\nTask: three lines.",
        "images": [base64.b64encode(b"first").decode(), base64.b64encode(b"second").decode()],
    }


def test_a_text_only_ollama_request_sends_no_images_and_no_unset_temperature():
    provider = OllamaProvider(
        "m", _settings(), ollama=OllamaSettings(url="http://x", context_tokens=4096)
    )
    body = provider.request(PROMPT, Answer.model_json_schema())
    assert "images" not in body["messages"][1] and "temperature" not in body["options"]


def test_ollama_is_never_handed_a_storage_uri():
    provider = OllamaProvider(
        "m", _settings(), ollama=OllamaSettings(url="http://x", context_tokens=4096)
    )
    with pytest.raises(ConfigError):
        provider.request(
            Prompt(system="s", parts=[ImagePart(mime_type="image/jpeg", uri="gs://b/o.jpg")]), {}
        )


# ── Vertex: the request it builds ─────────────────────────────────────────────


def _vertex(thinking="low", resolution="high", temperature=1.0) -> VertexProvider:
    return VertexProvider(
        "gemini-3.8-flash",
        _settings(spec="vertex/gemini-3.8-flash", max_output_tokens=2048, temperature=temperature),
        vertex=VertexSettings(
            location="us-central1", thinking_level=thinking, media_resolution=resolution
        ),
        client=None,
    )


def test_vertex_sends_thinking_level_media_resolution_and_temperature():
    from google.genai import types

    config = _vertex().generation_config("s", {"type": "object"})
    assert config.thinking_config.thinking_level == types.ThinkingLevel.LOW
    assert config.thinking_config.thinking_budget is None
    assert config.media_resolution == types.MediaResolution.MEDIA_RESOLUTION_HIGH
    assert config.temperature == 1.0
    assert config.response_mime_type == "application/json" and config.max_output_tokens == 2048


def test_vertex_does_not_send_what_is_unset():
    config = _vertex(thinking=None, resolution=None, temperature=None).generation_config("s", {})
    assert (
        config.thinking_config is None
        and config.media_resolution is None
        and config.temperature is None
    )


def test_vertex_is_handed_a_stored_screenshot_by_uri():
    parts = VertexProvider.contents(
        Prompt(
            system="s",
            parts=[
                ImagePart(mime_type="image/jpeg", uri="gs://bucket/users/u1/a.jpg"),
                ImagePart(mime_type="image/png", data=b"png"),
                TextPart(text="t"),
            ],
        )
    )
    assert parts[0].file_data.file_uri == "gs://bucket/users/u1/a.jpg"
    assert parts[1].inline_data.data == b"png" and parts[2].text == "t"


def test_vertex_usage_maps_to_token_counts():
    from google.genai import types

    usage = VertexProvider.usage(
        types.GenerateContentResponseUsageMetadata(
            prompt_token_count=5160,
            cached_content_token_count=3360,
            candidates_token_count=210,
            thoughts_token_count=480,
        )
    )
    assert (
        usage.prompt_tokens,
        usage.cached_tokens,
        usage.output_tokens,
        usage.thought_tokens,
    ) == (5160, 3360, 210, 480)
    assert VertexProvider.usage(None) is None  # not reported is not the same as zero


def test_ollama_usage_is_the_counts_it_reports():
    usage = OllamaProvider.usage({"prompt_eval_count": 812, "eval_count": 64})
    assert usage == TokenUsage(prompt_tokens=812, output_tokens=64)
    assert OllamaProvider.usage({"message": {"content": "{}"}}) is None


# ── failures, through the manager ─────────────────────────────────────────────


@pytest.mark.usefixtures("unreachable_model")
def test_an_unreachable_model_is_a_call_failure_and_is_measured():
    metrics = InMemoryMetrics()
    with pytest.raises(ModelCallFailed) as raised:
        _run_generate(_manager(metrics), PROMPT, Answer, operation="reply")
    assert "127.0.0.1:9" in str(raised.value)
    [call] = metrics.of(ModelCall)
    assert (call.provider, call.model, call.operation, call.outcome) == (
        "ollama",
        "unreachable:test",
        "reply",
        "call_failed",
    )


def test_a_model_that_is_not_pulled_says_how_to_get_it(monkeypatch, ollama_server):
    monkeypatch.setenv("AI_MODEL", "ollama/not-pulled-anywhere:0")
    with pytest.raises(ModelCallFailed) as raised:
        _run_generate(_manager(), PROMPT, Answer, operation="reply")
    assert "ollama pull not-pulled-anywhere:0" in str(raised.value)


def test_a_stored_screenshot_without_a_blob_reader_is_a_config_error():
    prompt = Prompt(
        system="s", parts=[ImagePart(mime_type="image/jpeg", uri="gs://in-memory/a.jpg")]
    )
    metrics = InMemoryMetrics()
    with pytest.raises(ConfigError):
        _run_generate(_manager(metrics), prompt, Answer, operation="express")
    assert metrics.of(ModelCall)[0].outcome == "config_error"


# ── the local model ───────────────────────────────────────────────────────────


def test_the_local_model_answers_in_the_shape_asked_for_and_the_call_is_measured(local_model):
    metrics = InMemoryMetrics()
    prompt = Prompt(
        system="You are a negotiation coach.",
        parts=[TextPart(text="The seller asks $180 for a shelf. Reply in one sentence.")],
    )

    generated = _run_generate(_manager(metrics), prompt, ReplyAnswer, operation="reply")

    assert isinstance(generated.answer, ReplyAnswer) and generated.answer.reply
    [call] = metrics.of(ModelCall)
    assert (call.provider, call.model, call.outcome) == ("ollama", local_model, "ok")
    assert call.prompt_tokens > 0 and call.output_tokens > 0 and call.latency_ms > 0
    # the caller gets what the metric measured, to record next to what it writes
    assert generated.model == local_model
    assert generated.usage == TokenUsage(
        prompt_tokens=call.prompt_tokens, output_tokens=call.output_tokens
    )


def test_a_stored_screenshot_reaches_a_local_model_as_bytes(local_model):
    """Ollama cannot read `gs://`: the manager fetches the object through its blob reader."""
    store = InMemoryScreenshotStore()
    path = store.add("u1", "c1", _jpeg())
    prompt = Prompt(
        system="Describe images.",
        parts=[
            ImagePart(mime_type="image/jpeg", uri=store.uri(path)),
            TextPart(text="What colour is this image? One word."),
        ],
    )
    metrics = InMemoryMetrics()

    generated = _run_generate(
        _manager(metrics, blobs=store), prompt, ReplyAnswer, operation="reply"
    )

    assert generated.answer.reply
    assert metrics.of(ModelCall)[0].images == 1


def test_upstream_errors_share_one_client_message():
    for error in (ModelCallFailed("x"), InvalidModelAnswer("y"), UpstreamError("z")):
        assert error.status == 502 and error.code == "UPSTREAM_ERROR"
        assert error.public_message == "The wizard could not answer right now. Try again."


def test_stored_screenshots_are_inlined_and_everything_else_is_kept():
    from core.ai.images import StoredImageInliner

    store = InMemoryScreenshotStore()
    path = store.add("u1", "c1", b"jpeg bytes")
    prompt = Prompt(
        system="s",
        parts=[
            ImagePart(mime_type="image/jpeg", uri=store.uri(path)),
            ImagePart(mime_type="image/png", data=b"png"),
            TextPart(text="t"),
        ],
    )

    inlined = asyncio.run(StoredImageInliner(store).inline(prompt))

    assert [part.data for part in inlined.images] == [b"jpeg bytes", b"png"]
    assert all(part.uri is None for part in inlined.images) and inlined.texts == ["t"]
    text_only = Prompt(system="s", parts=[TextPart(text="t")])
    # nothing to read, so no reader is needed
    assert asyncio.run(StoredImageInliner(None).inline(text_only)) is text_only
