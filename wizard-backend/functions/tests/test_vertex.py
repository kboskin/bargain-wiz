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
