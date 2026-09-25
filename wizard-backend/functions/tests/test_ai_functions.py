"""HTTP-level tests for express_dealmaker / pro_deal_closer.

Validation, auth and failure mapping ask no model; the answers come from the local model."""

import base64
import io
import json

import pytest
from flask import Flask, request
from PIL import Image as PilImage

import main
from core.observability import ModelCall
from support import InMemoryMetrics, StaticAuthenticator, call, install

INTENTS = {"opener", "counter", "close"}


def _jpeg() -> str:
    buf = io.BytesIO()
    PilImage.new("RGB", (120, 80), "white").save(buf, format="JPEG")
    return base64.b64encode(buf.getvalue()).decode()


VIBE_PROMPTS = {
    "friendly": "Friendly Collaborator: warm and polite, still anchors below the asking price.",
    "no_nonsense": "No-Nonsense Buyer: direct and brief, states numbers plainly.",
}


def _profile(vibe="friendly", locale="en") -> dict:
    """The profile as the app sends it: one entry per pick, each carrying its own line."""
    return {
        "answers": [
            {"key": "vibe", "value": vibe, "prompt": VIBE_PROMPTS.get(vibe, f"Tone: {vibe}.")},
            {"key": "push", "value": 60, "prompt": "Push level: Balanced — a fair anchor."},
        ],
        "locale": locale,
    }


@pytest.fixture
def metrics(monkeypatch) -> InMemoryMetrics:
    metrics = InMemoryMetrics()
    install(monkeypatch, metrics=metrics, authenticator=StaticAuthenticator(None))
    return metrics


def _post(function, body, **kwargs):
    if isinstance(body, dict) and "profile" not in body:
        body = {"profile": _profile(), **body}
    status, response, _ = call(function, "POST", "/", body, **kwargs)
    return status, response


# ── no model needed ───────────────────────────────────────────────────────────


def test_express_rejects_empty_and_non_post(metrics):
    status, body = _post(main.express_dealmaker, {})
    assert status == 400 and body["error"]["status"] == "INVALID_ARGUMENT"
    status, body, _ = call(main.express_dealmaker, "GET", "/")
    assert status == 405 and body["error"]["status"] == "METHOD_NOT_ALLOWED"
    assert metrics.of(ModelCall) == []  # rejected before any model was asked


def test_express_rejects_an_invalid_bearer_token(monkeypatch):
    install(monkeypatch, authenticator=StaticAuthenticator(None, invalid_token=True))
    status, body = _post(
        main.express_dealmaker, {"text": "x"}, headers={"Authorization": "Bearer nope"}
    )
    assert status == 401 and body["error"]["status"] == "UNAUTHENTICATED"


def test_pro_validation(metrics):
    status, body = _post(main.pro_deal_closer, {"messages": []})
    assert status == 400 and body["error"]["status"] == "INVALID_ARGUMENT"
    status, body = _post(
        main.pro_deal_closer, {"messages": [{"role": "user", "text": "x"}], "mode": "essay"}
    )
    assert status == 400


@pytest.mark.usefixtures("unreachable_model")
def test_a_model_outage_is_a_502_that_leaks_nothing(metrics):
    status, body = _post(main.express_dealmaker, {"text": "Selling bike $300"})
    assert status == 502 and body["error"]["status"] == "UPSTREAM_ERROR"
    assert "127.0.0.1" not in body["error"]["message"]  # internals never leak
    assert metrics.of(ModelCall)[0].outcome == "call_failed"


# ── the local model ───────────────────────────────────────────────────────────


def _assert_lines(lines):
    assert 1 <= len(lines) <= 3
    for line in lines:
        assert line["intent"] in INTENTS and line["text"].strip()
        assert set(line) == {"intent", "text", "why"}


def test_express_returns_seeing_and_lines_from_screenshots(metrics, local_model):
    status, body = _post(
        main.express_dealmaker,
        {
            "images": [{"mime_type": "image/jpeg", "data": _jpeg()}],
            "text": "IKEA Kallax, $180, slight scuff",
            "keyword": "scuff",
        },
    )
    assert status == 200, body
    assert set(body) == {"seeing", "lines", "model"} and body["model"] == local_model
    assert body["seeing"].strip()
    _assert_lines(body["lines"])
    [model_call] = metrics.of(ModelCall)
    assert (model_call.operation, model_call.outcome, model_call.images) == ("express", "ok", 1)


def test_pro_reply_and_options(metrics, local_model):
    messages = [{"role": "user", "text": "Kallax listed at $180, what do I say?"}]
    status, body = _post(main.pro_deal_closer, {"messages": messages})
    assert status == 200 and set(body) == {"reply", "model"} and body["reply"].strip()

    status, body = _post(main.pro_deal_closer, {"messages": messages, "mode": "options"})
    assert status == 200 and set(body) == {"lines", "model"}
    _assert_lines(body["lines"])
    assert [c.operation for c in metrics.of(ModelCall)] == ["reply", "options"]


def test_express_accepts_json_without_content_type(metrics, local_model):
    with Flask(__name__).test_request_context(
        "/",
        method="POST",
        data=json.dumps({"profile": _profile(), "text": "bike $300"}),
        content_type="text/plain",
    ):
        res = main.express_dealmaker(request)
    assert res.status_code == 200
