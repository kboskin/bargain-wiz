"""HTTP-level tests for express_dealmaker / pro_deal_closer with a fake Gemini."""
import base64
import json

import pytest
from flask import Flask, request

import main
from vertex import UpstreamError

PNG = base64.b64encode(b"\x89PNG\r\n\x1a\n" + b"0" * 64).decode()
LINES = [
    {"intent": "opener", "text": "Is the Kallax still available? $140 cash today.", "why": "Anchors low."},
    {"intent": "counter", "text": "$160 is my max.", "why": "Firm ceiling."},
    {"intent": "close", "text": "Deal at $160. Send the address.", "why": "Closes."},
]


class FakeGenerator:
    model = "fake-gemini"

    def __init__(self, result=None, error=None):
        self.result, self.error, self.calls = result, error, []

    def generate_json(self, *, system, parts, schema):
        self.calls.append({"system": system, "parts": parts, "schema": schema})
        if self.error:
            raise self.error
        return self.result


@pytest.fixture
def fake(monkeypatch):
    def install(result=None, error=None):
        gen = FakeGenerator(result, error)
        monkeypatch.setattr(main, "_generator", gen)
        return gen

    return install


def _post(func, body, method="POST", headers=None):
    app = Flask(__name__)
    with app.test_request_context("/", method=method, json=body, headers=headers or {}):
        res = func(request)
    return res.status_code, json.loads(res.get_data(as_text=True))


def test_express_returns_seeing_and_lines(fake):
    gen = fake({"seeing": "IKEA Kallax · $180", "lines": LINES})
    status, body = _post(
        main.express_dealmaker,
        {"images": [{"mime_type": "image/png", "data": PNG}], "keyword": "scuff", "vibe": "no_nonsense", "locale": "en"},
    )
    assert status == 200
    assert body["seeing"] == "IKEA Kallax · $180"
    assert [line["intent"] for line in body["lines"]] == ["opener", "counter", "close"]
    assert body["model"] == "fake-gemini"
    call = gen.calls[0]
    assert "No-Nonsense" in call["system"]
    assert call["parts"][0]["type"] == "image" and call["schema"] is main.EXPRESS_SCHEMA


def test_express_accepts_text_only(fake):
    fake({"seeing": "Text listing", "lines": LINES[:1]})
    status, body = _post(main.express_dealmaker, {"text": "Selling bike $300, some rust"})
    assert status == 200 and len(body["lines"]) == 1


def test_express_rejects_empty_and_non_post(fake):
    fake({"seeing": "", "lines": LINES})
    status, body = _post(main.express_dealmaker, {})
    assert status == 400 and body["error"]["status"] == "INVALID_ARGUMENT"
    status, body = _post(main.express_dealmaker, None, method="GET")
    assert status == 405


def test_express_maps_model_failures_to_502(fake):
    fake(error=UpstreamError("quota"))
    status, body = _post(main.express_dealmaker, {"text": "x"})
    assert status == 502 and body["error"]["status"] == "UPSTREAM_ERROR"
    fake({"seeing": "x", "lines": []})
    status, body = _post(main.express_dealmaker, {"text": "x"})
    assert status == 502


def test_express_rejects_invalid_bearer_token(fake, monkeypatch):
    fake({"seeing": "x", "lines": LINES})
    import runtime

    def boom(req):
        raise runtime.Unauthorized("bad token")

    monkeypatch.setattr(main, "optional_uid", boom)
    status, body = _post(main.express_dealmaker, {"text": "x"}, headers={"Authorization": "Bearer nope"})
    assert status == 401 and body["error"]["status"] == "UNAUTHENTICATED"


def test_pro_reply_and_options(fake):
    gen = fake({"reply": "Open at $140 and offer pickup today."})
    messages = [{"role": "user", "text": "Kallax listed at $180, what do I say?"}]
    status, body = _post(main.pro_deal_closer, {"messages": messages, "vibe": "friendly"})
    assert status == 200 and body["reply"].startswith("Open at $140")
    assert gen.calls[0]["schema"] is main.REPLY_SCHEMA

    gen = fake({"lines": LINES})
    status, body = _post(main.pro_deal_closer, {"messages": messages, "mode": "options"})
    assert status == 200 and len(body["lines"]) == 3
    assert gen.calls[0]["schema"] is main.OPTIONS_SCHEMA


def test_pro_validation(fake):
    fake({"reply": "x"})
    status, body = _post(main.pro_deal_closer, {"messages": []})
    assert status == 400 and body["error"]["status"] == "INVALID_ARGUMENT"


def test_express_accepts_json_without_content_type(fake):
    fake({"seeing": "x", "lines": LINES})
    app = Flask(__name__)
    with app.test_request_context("/", method="POST", data=json.dumps({"text": "bike $300"}), content_type="text/plain"):
        res = main.express_dealmaker(request)
    assert res.status_code == 200
