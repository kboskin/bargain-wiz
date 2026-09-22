"""Tests for the generator surface: a call constrained to a pydantic model comes back as one.

The Vertex call itself (`_respond`) is stubbed — these cover what the functions depend on: a
validated instance, or an [UpstreamError] that says what the model got wrong.
"""
import pytest
from pydantic import BaseModel

from core.ai.vertex import VertexGenerator
from core.errors import UpstreamError


class Answer(BaseModel):
    value: str


class FakeResponse:
    """What google-genai returns: `parsed` is filled only when the answer fits the schema."""

    def __init__(self, parsed=None, text=None):
        self.parsed, self.text = parsed, text


def _generator(response) -> VertexGenerator:
    """A generator without the SDK client: construction needs credentials, the call does not."""
    generator = object.__new__(VertexGenerator)
    generator.model = "fake-gemini"
    generator._respond = lambda **_: response
    return generator


def _generate(response, model=Answer):
    return _generator(response).generate(system="s", parts=[{"type": "text", "text": "t"}], response_model=model)


def test_the_parsed_answer_is_returned_as_the_model():
    answer = Answer(value="hi")
    assert _generate(FakeResponse(parsed=answer)) is answer


def test_an_answer_the_sdk_did_not_parse_is_validated_here():
    """`parsed` stays empty when the SDK could not validate (streaming, a truncated reply);
    the text is the same JSON, so validate it rather than fail."""
    assert _generate(FakeResponse(text='{"value": "hi"}')) == Answer(value="hi")


@pytest.mark.parametrize("text", ['{"other": 1}', "not json", ""])
def test_an_answer_that_does_not_fit_the_model_is_an_upstream_error(text):
    with pytest.raises(UpstreamError):
        _generate(FakeResponse(text=text))


def test_the_upstream_error_names_the_model_and_the_field():
    with pytest.raises(UpstreamError) as raised:
        _generate(FakeResponse(text='{"other": 1}'))
    assert "Answer" in str(raised.value) and "value" in str(raised.value)
    assert raised.value.status == 502
    assert "wizard could not answer" in raised.value.public_message


def test_generate_json_still_decodes_a_hand_written_schema():
    generator = _generator(FakeResponse(text='{"reply": "sure"}'))
    assert generator.generate_json(system="s", parts=[], schema={"type": "object"}) == {"reply": "sure"}

    with pytest.raises(UpstreamError):
        _generator(FakeResponse(text="[1, 2]")).generate_json(system="s", parts=[], schema={"type": "object"})


# ── generation settings (Gemini 3) and usage logging ────────────────────────


def _settings(thinking="low", resolution="high", temperature=1.0) -> VertexGenerator:
    generator = object.__new__(VertexGenerator)
    generator.model = "gemini-3.8-flash"
    generator._max_output_tokens = 2048
    generator._temperature = temperature
    generator._thinking_level = thinking
    generator._media_resolution = resolution
    return generator


def test_generation_config_sends_thinking_level_media_resolution_and_temperature():
    from google.genai import types

    cfg = _settings()._generation_config(system="s", schema={"type": "object"})
    assert cfg.thinking_config.thinking_level == types.ThinkingLevel.LOW
    assert cfg.thinking_config.thinking_budget is None
    assert cfg.media_resolution == types.MediaResolution.MEDIA_RESOLUTION_HIGH
    assert cfg.temperature == 1.0
    assert cfg.response_mime_type == "application/json" and cfg.max_output_tokens == 2048


def test_unset_generation_settings_are_not_sent():
    cfg = _settings(thinking=None, resolution=None, temperature=None)._generation_config(system="s", schema={})
    assert cfg.thinking_config is None and cfg.media_resolution is None and cfg.temperature is None


@pytest.mark.parametrize(
    ("name", "raw", "allowed", "expected"),
    [
        ("VERTEX_THINKING_LEVEL", " Low ", ("low", "medium", "high"), "low"),
        ("VERTEX_THINKING_LEVEL", "", ("low", "medium", "high"), None),
        ("VERTEX_MEDIA_RESOLUTION", "medium", ("low", "medium", "high"), "medium"),
    ],
)
def test_config_choices_normalise_and_allow_empty(name, raw, allowed, expected):
    from core.ai.vertex import _optional_choice

    assert _optional_choice(name, raw, allowed) == expected


def test_an_unknown_choice_or_temperature_fails_loudly():
    from core.ai.vertex import _optional_choice, _optional_float

    with pytest.raises(UpstreamError) as raised:
        _optional_choice("VERTEX_THINKING_LEVEL", "minimal", ("low", "medium", "high"))
    assert "VERTEX_THINKING_LEVEL" in str(raised.value) and "minimal" in str(raised.value)
    with pytest.raises(UpstreamError):
        _optional_float("VERTEX_TEMPERATURE", "warm")
    assert _optional_float("VERTEX_TEMPERATURE", "") is None


class FakeUsage:
    prompt_token_count = 5160
    cached_content_token_count = 3360
    candidates_token_count = 210
    thoughts_token_count = 480
    total_token_count = 5850


def test_usage_is_logged_per_call_with_thinking_and_cache_counts(caplog):
    from core.ai.vertex import log_usage

    with caplog.at_level("INFO", logger="vertex"):
        log_usage("gemini-3.8-flash", FakeUsage())
        log_usage("gemini-3.8-flash", None)  # a stubbed or streaming response without metadata
    lines = [r.getMessage() for r in caplog.records]
    assert lines == [
        (
            "gemini usage model=gemini-3.8-flash prompt_tokens=5160 cached_tokens=3360 "
            "output_tokens=210 thought_tokens=480 total_tokens=5850"
        )
    ]
