"""HTTP-level tests for express_dealmaker / pro_deal_closer with a fake Gemini."""
import base64
import json

import pytest
from flask import Flask, request

import main
from core.auth.firebase import StaticAuthenticator
from core.errors import UpstreamError
from features.negotiation.domain.lines import EXPRESS_SCHEMA, OPTIONS_SCHEMA, REPLY_SCHEMA

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


@pytest.fixture(autouse=True)
def _restore_main(monkeypatch):
    """Tests swap the constructors `main` uses for fakes; monkeypatch puts the real ones back."""
    monkeypatch.setattr(main, "VertexGenerator", main.VertexGenerator)
    monkeypatch.setattr(main, "FirebaseAuthenticator", main.FirebaseAuthenticator)


# The app always sends the buyer's tone and push level; `_post` adds them so each test can
# say only what it is about.
# What each tone means is the template's to say, and the app forwards it with every request
# (AI_INTEGRATION.md) — there is no server-side tone list any more, so a fixture that omitted
# this would produce a prompt with no Tone line.
VIBE_PROMPTS = {
    "friendly": "Friendly Collaborator: warm and polite, still anchors below the asking price.",
    "no_nonsense": "No-Nonsense Buyer: direct and brief, states numbers plainly.",
    "tactical": "Tactical Strategist: uses comparable prices and flaws as leverage.",
    "quiet_closer": "Quiet Closer: low-pressure, yet always moves the deal to a close.",
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


def _install(result=None, error=None, auth=None):
    """Make the functions use a fake Gemini (and identity); returns the function map and the fake."""
    gen = FakeGenerator(result, error)
    main.VertexGenerator = lambda: gen
    main.FirebaseAuthenticator = lambda: auth or StaticAuthenticator(None)
    return {"/express_dealmaker": main.express_dealmaker, "/pro_deal_closer": main.pro_deal_closer}, gen


def _post(path, functions, body, method="POST", headers=None, profile=True):
    app = Flask(__name__)
    if profile and isinstance(body, dict):
        # `vibe` and `locale` are written flat by the callers below for brevity; the wire nests them.
        body = dict(body)
        vibe, locale = body.pop("vibe", "friendly"), body.pop("locale", "en")
        body = {"profile": _profile(vibe, locale), **body}
    with app.test_request_context(path, method=method, json=body, headers=headers or {}):
        res = functions[path](request)
    return res.status_code, json.loads(res.get_data(as_text=True))


def test_express_returns_seeing_and_lines():
    c, gen = _install({"seeing": "IKEA Kallax · $180", "lines": LINES})
    status, body = _post(
        "/express_dealmaker",
        c,
        {"images": [{"mime_type": "image/png", "data": PNG}], "keyword": "scuff", "vibe": "no_nonsense", "locale": "en"},
    )
    assert status == 200
    assert body["seeing"] == "IKEA Kallax · $180"
    assert [line["intent"] for line in body["lines"]] == ["opener", "counter", "close"]
    assert body["model"] == "fake-gemini"
    call = gen.calls[0]
    assert "No-Nonsense" in call["system"]
    assert call["parts"][0]["type"] == "image" and call["schema"] is EXPRESS_SCHEMA


def test_express_accepts_text_only():
    c, _ = _install({"seeing": "Text listing", "lines": LINES[:1]})
    status, body = _post("/express_dealmaker", c, {"text": "Selling bike $300, some rust"})
    assert status == 200 and len(body["lines"]) == 1


def test_express_rejects_empty_and_non_post():
    c, _ = _install({"seeing": "", "lines": LINES})
    status, body = _post("/express_dealmaker", c, {}, profile=False)
    assert status == 400 and body["error"]["status"] == "INVALID_ARGUMENT"
    status, body = _post("/express_dealmaker", c, None, method="GET")
    assert status == 405 and body["error"]["status"] == "METHOD_NOT_ALLOWED"


def test_express_maps_model_failures_to_502():
    c, _ = _install(error=UpstreamError("quota"))
    status, body = _post("/express_dealmaker", c, {"text": "x"})
    assert status == 502 and body["error"]["status"] == "UPSTREAM_ERROR"
    assert "quota" not in body["error"]["message"]  # internals never leak
    c, _ = _install({"seeing": "x", "lines": []})
    status, body = _post("/express_dealmaker", c, {"text": "x"})
    assert status == 502 and body["error"]["status"] == "UPSTREAM_ERROR"


def test_unexpected_exceptions_are_a_bare_500():
    c, _ = _install(error=RuntimeError("secret detail"))
    status, body = _post("/express_dealmaker", c, {"text": "x"})
    assert status == 500 and body["error"] == {"status": "INTERNAL", "message": "Unexpected error."}


def test_express_rejects_invalid_bearer_token():
    c, _ = _install({"seeing": "x", "lines": LINES}, auth=StaticAuthenticator(None, invalid_token=True))
    status, body = _post("/express_dealmaker", c, {"text": "x"}, headers={"Authorization": "Bearer nope"})
    assert status == 401 and body["error"]["status"] == "UNAUTHENTICATED"


def test_pro_reply_and_options():
    c, gen = _install({"reply": "Open at $140 and offer pickup today."})
    messages = [{"role": "user", "text": "Kallax listed at $180, what do I say?"}]
    status, body = _post("/pro_deal_closer", c, {"messages": messages, "vibe": "friendly"})
    assert status == 200 and body["reply"].startswith("Open at $140")
    assert gen.calls[0]["schema"] is REPLY_SCHEMA

    c, gen = _install({"lines": LINES})
    status, body = _post("/pro_deal_closer", c, {"messages": messages, "mode": "options"})
    assert status == 200 and len(body["lines"]) == 3
    assert gen.calls[0]["schema"] is OPTIONS_SCHEMA


def test_pro_validation():
    c, _ = _install({"reply": "x"})
    status, body = _post("/pro_deal_closer", c, {"messages": []})
    assert status == 400 and body["error"]["status"] == "INVALID_ARGUMENT"


def test_express_accepts_json_without_content_type():
    _install({"seeing": "x", "lines": LINES})
    app = Flask(__name__)
    with app.test_request_context("/", method="POST", data=json.dumps({"profile": _profile(), "text": "bike $300"}), content_type="text/plain"):
        res = main.express_dealmaker(request)
    assert res.status_code == 200
