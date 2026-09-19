"""HTTP-level tests for the `conversations` function with an in-memory store and a fake Gemini."""
import base64
import io
import json
from datetime import UTC, datetime

import pytest
from flask import Flask, request
from PIL import Image as PilImage

import main
from core.auth.firebase import AuthInfo, FirebaseAuthenticator, StaticAuthenticator
from core.errors import Unauthorized, UpstreamError
from features.conversations.data.dispatchers import InlineDispatcher
from features.conversations.data.store import InMemoryConversationStore
from features.conversations.domain.models import GenerationTask
from features.conversations.domain.service import ConversationService
from features.negotiation.domain.lines import EXPRESS_SCHEMA, OPTIONS_SCHEMA, REPLY_SCHEMA

NOW = datetime(2026, 9, 17, 12, tzinfo=UTC)
LINES = [
    {"intent": "opener", "text": "Is the Kallax still available? $140 cash today.", "why": "Anchors low."},
    {"intent": "counter", "text": "$160 is my max.", "why": "Firm ceiling."},
    {"intent": "close", "text": "Deal at $160. Send the address.", "why": "Closes."},
]


def _png(width=40, height=30) -> str:
    buf = io.BytesIO()
    PilImage.new("RGB", (width, height), "blue").save(buf, format="PNG")
    return base64.b64encode(buf.getvalue()).decode()


PNG = _png()
IMG = {"mime_type": "image/png", "data": PNG}


class FakeGenerator:
    model = "fake-gemini"

    def __init__(self):
        self.results: list = []
        self.calls: list[dict] = []

    def queue(self, *results):
        self.results.extend(results)
        return self

    def generate_json(self, *, system, parts, schema):
        self.calls.append({"system": system, "parts": parts, "schema": schema})
        result = self.results.pop(0) if self.results else {"reply": "Open at $140."}
        if isinstance(result, Exception):
            raise result
        return result


@pytest.fixture
def store():
    return InMemoryConversationStore(clock=lambda: NOW)


@pytest.fixture
def gen():
    return FakeGenerator()


U1 = AuthInfo(uid="u1", provider="anonymous")


def _service(store, gen, dispatcher=None, monkeypatch=None):
    """A service the `conversations` function will use. The default dispatcher runs the
    worker inline, so a test can assert the finished state in one call."""
    holder: dict = {}
    svc = ConversationService(store, gen, dispatcher or InlineDispatcher(lambda: holder["svc"]))
    holder["svc"] = svc
    if monkeypatch is not None:
        monkeypatch.setattr(main, "conversation_service", lambda: svc)
        monkeypatch.setattr(main, "FirebaseAuthenticator", lambda: StaticAuthenticator(U1))
    return svc


@pytest.fixture
def service(monkeypatch, store, gen):
    return _service(store, gen, monkeypatch=monkeypatch)


def _message(store, cid, mid):
    return next(m for m in store.list_messages("u1", cid) if m["id"] == mid)


# Every write carries the buyer's profile, exactly as the app sends it.
PROFILE = {"vibe": "friendly", "push": 60}


def _call(method, path, body=None, profile=True):
    if profile and isinstance(body, dict):
        body = {**PROFILE, **body}
    with Flask(__name__).test_request_context(path, method=method, json=body):
        res = main.conversations(request)
    return res.status_code, json.loads(res.get_data(as_text=True))


def _start_pro(text="They ask $180 for the Kallax", images=None, **profile):
    return _call("POST", "/conversations", {"type": "pro", "text": text, "images": images or [],
                                           "vibe": "no_nonsense", "locale": "en", **profile})


# ── pro chat ──────────────────────────────────────────────────────────────────


def test_first_turn_stores_user_and_wizard_messages_and_the_screenshot(service, store, gen):
    gen.queue({"reply": "Open at $140, pickup today."})
    status, body = _start_pro(images=[IMG])

    assert status == 200
    cid, mid, rid = body["conversation_id"], body["message_id"], body["reply_id"]
    conv = store.get_conversation("u1", cid)
    assert conv["type"] == "pro" and conv["status"] == "open" and conv["vibe"] == "no_nonsense"
    assert conv["active"] is True
    assert conv["message_count"] == 2 and "active_turn" not in conv
    assert conv["title"] == "They ask $180 for the Kallax"
    assert conv["preview"] == "Open at $140, pickup today."
    assert conv["thumbnail"]["path"].startswith(f"users/u1/conversations/{cid}/")
    assert conv["created_at"] == NOW and conv["last_message_at"] == NOW

    user, wizard = store.list_messages("u1", cid)
    assert (user["id"], wizard["id"]) == (mid, rid)
    assert user["role"] == "user" and user["seq"] == 1 and user["status"] == "done"
    assert user["reply_id"] == rid
    ref = user["images"][0]
    assert ref["mime_type"] == "image/jpeg" and ref["width"] == 40 and ref["height"] == 30
    stored = store.get_image(ref["path"])
    assert stored[:3] == b"\xff\xd8\xff"  # re-encoded as JPEG, no PNG left
    assert wizard["role"] == "wizard" and wizard["seq"] == 2 and wizard["status"] == "done"
    assert wizard["text"] == "Open at $140, pickup today." and wizard["model"] == "fake-gemini"
    assert wizard["revision"] == 0 and "latency_ms" in wizard

    call = gen.calls[0]
    assert "No-Nonsense" in call["system"] and call["schema"] is REPLY_SCHEMA
    assert call["parts"][0]["type"] == "image" and call["parts"][0]["data"] == stored
    assert "Buyer: They ask $180 for the Kallax (screenshot attached)" in call["parts"][-1]["text"]


def test_follow_up_sends_only_the_new_message_and_uses_stored_history(service, store, gen):
    gen.queue({"reply": "Open at $140."}, {"reply": "Hold at $150."})
    _, first = _start_pro(images=[IMG])
    cid = first["conversation_id"]

    status, body = _call("POST", f"/conversations/{cid}/messages",
                         {"text": "Seller says $170 is final", "vibe": "tactical"})

    assert status == 200 and body["conversation_id"] == cid
    messages = store.list_messages("u1", cid)
    assert [m["seq"] for m in messages] == [1, 2, 3, 4]
    assert messages[3]["text"] == "Hold at $150."
    transcript = gen.calls[1]["parts"][-1]["text"]
    assert "Wizard: Open at $140." in transcript and "Buyer: Seller says $170 is final" in transcript
    assert gen.calls[1]["parts"][0]["type"] == "image"  # the stored screenshot is reused
    assert "Tactical" in gen.calls[1]["system"]
    assert store.get_conversation("u1", cid)["vibe"] == "tactical"


def test_a_second_options_request_while_one_is_pending_does_not_queue_another(service, store, gen):
    """No client key dedupes writes any more: `pending_options` on the message is the guard,
    and it survives an app restart in a way a per-process id never did."""
    gen.queue({"reply": "Open at $140."})
    _, first = _start_pro()
    cid, rid = first["conversation_id"], first["reply_id"]
    store.set_message("u1", cid, rid, {"pending_options": True}, merge=True)

    status, body = _call("POST", f"/conversations/{cid}/options", {})

    assert status == 200 and body["message_id"] == rid
    assert len(gen.calls) == 1  # still just the reply


def test_sending_while_the_wizard_is_typing_is_rejected(service, store, gen):
    _, first = _start_pro()
    cid = first["conversation_id"]
    store.set_conversation("u1", cid, {"active_turn": {"message_id": "x"}}, merge=True)

    status, body = _call("POST", f"/conversations/{cid}/messages", {"text": "hi"})

    assert status == 409 and body["error"]["status"] == "TURN_IN_PROGRESS"


def test_model_failure_marks_the_reply_failed_and_frees_the_conversation(service, store, gen):
    gen.queue(UpstreamError("boom"), {"reply": "Recovered."})
    status, body = _start_pro()
    # The turn was accepted; the failure reaches the app through the listener, not the response.
    assert status == 200

    cid = body["conversation_id"]
    conv = store.get_conversation("u1", cid)
    assert "active_turn" not in conv
    wizard = store.list_messages("u1", cid)[1]
    assert wizard["status"] == "failed" and wizard["error"]["code"] == "UPSTREAM_ERROR"

    status, _ = _call("POST", f"/conversations/{cid}/messages", {"text": "retry"})
    assert status == 200
    assert store.list_messages("u1", cid)[-1]["text"] == "Recovered."


def test_options_attach_lines_to_the_wizard_reply(service, store, gen):
    gen.queue({"reply": "Open at $140."}, {"lines": LINES})
    _, first = _start_pro()
    cid, rid = first["conversation_id"], first["reply_id"]

    status, body = _call("POST", f"/conversations/{cid}/options", {"vibe": "friendly"})

    assert status == 200 and body["message_id"] == rid
    wizard = _message(store, cid, rid)
    assert [line["intent"] for line in wizard["lines"]] == ["opener", "counter", "close"]
    assert "pending_options" not in wizard  # the spinner is cleared when the lines land
    assert gen.calls[1]["schema"] is OPTIONS_SCHEMA


def test_redo_regenerates_in_place_and_clears_options(service, store, gen):
    gen.queue({"reply": "Open at $140."}, {"lines": LINES}, {"reply": "Try $135 with pickup tonight."})
    _, first = _start_pro()
    cid, rid = first["conversation_id"], first["reply_id"]
    _call("POST", f"/conversations/{cid}/options", {})

    status, body = _call("POST", f"/conversations/{cid}/redo", {"vibe": "quiet_closer"})

    assert status == 200 and body["message_id"] == rid
    wizard = _message(store, cid, rid)
    assert wizard["text"] == "Try $135 with pickup tonight." and wizard["revision"] == 1
    assert wizard["status"] == "done" and "lines" not in wizard
    assert "different angle" in gen.calls[2]["parts"][-1]["text"]
    assert "Quiet" in gen.calls[2]["system"]
    conv = store.get_conversation("u1", cid)
    assert conv["preview"] == "Try $135 with pickup tonight." and "active_turn" not in conv


# ── express ───────────────────────────────────────────────────────────────────


def test_express_conversation_returns_and_stores_seeing_and_lines(service, store, gen):
    gen.queue({"seeing": "IKEA Kallax · $180 · slight scuff", "lines": LINES})

    status, body = _call("POST", "/conversations", {
        "type": "express", "keyword": "scuff", "vibe": "tactical", "locale": "es",
        "images": [IMG, IMG],
    })

    assert status == 200
    assert set(body) == {"conversation_id", "message_id", "reply_id"}  # the result arrives via the listener
    cid = body["conversation_id"]
    conv = store.get_conversation("u1", cid)
    assert conv["express"]["seeing"] == "IKEA Kallax · $180 · slight scuff"
    assert [line["intent"] for line in conv["express"]["lines"]] == ["opener", "counter", "close"]
    assert conv["type"] == "express" and conv["keyword"] == "scuff"
    assert conv["title"] == "IKEA Kallax · $180 · slight scuff"
    assert conv["express"]["keyword"] == "scuff"
    assert [ref["path"] for ref in conv["express"]["images"]] == [ref["path"] for ref in store.list_messages("u1", cid)[0]["images"]]
    user, wizard = store.list_messages("u1", cid)
    assert len(user["images"]) == 2 and wizard["seeing"] == conv["express"]["seeing"] and wizard["lines"] == LINES
    call = gen.calls[0]
    assert call["schema"] is EXPRESS_SCHEMA and "locale tag es" in call["system"]
    assert sum(1 for p in call["parts"] if p["type"] == "image") == 2
    assert "focus on: scuff" in call["parts"][-1]["text"]


def test_express_redo_regenerates_with_the_new_tone_and_keyword(service, store, gen):
    gen.queue({"seeing": "Kallax", "lines": LINES}, {"seeing": "Kallax", "lines": LINES[:2]})
    _, first = _call("POST", "/conversations", {"type": "express", "images": [IMG]})
    cid = first["conversation_id"]

    status, _ = _call("POST", f"/conversations/{cid}/redo",
                      {"vibe": "friendly", "keyword": "pickup"})

    assert status == 200
    conv = store.get_conversation("u1", cid)
    assert len(conv["express"]["lines"]) == 2
    assert conv["vibe"] == "friendly" and conv["keyword"] == "pickup" and conv["express"]["keyword"] == "pickup"
    assert "Friendly" in gen.calls[1]["system"] and "focus on: pickup" in gen.calls[1]["parts"][-1]["text"]
    assert store.list_messages("u1", cid)[1]["revision"] == 1


def test_express_redo_after_a_failed_generation_reuses_the_stored_screenshots(service, store, gen):
    """What the app's Retry does: the failed deal is regenerated in place, so a turn that broke
    never costs a second conversation (wizard-app express retry)."""
    gen.queue(UpstreamError("boom"), {"seeing": "Kallax", "lines": LINES})
    _, first = _call("POST", "/conversations", {"type": "express", "keyword": "scuff", "images": [IMG]})
    cid = first["conversation_id"]
    failed = store.get_conversation("u1", cid)
    assert failed["last_error"]["code"] == "UPSTREAM_ERROR" and "active_turn" not in failed

    status, body = _call("POST", f"/conversations/{cid}/redo", {"vibe": "friendly"})

    assert status == 200 and body["conversation_id"] == cid
    conv = store.get_conversation("u1", cid)
    assert conv["express"]["lines"] == LINES and "last_error" not in conv
    assert conv["express"]["keyword"] == "scuff"  # kept: the retry carries no new one
    assert len(store.list_conversations("u1")) == 1
    # The screenshots travelled once: the regeneration read them back from the stored turn.
    assert sum(1 for p in gen.calls[1]["parts"] if p["type"] == "image") == 1
    wizard = store.list_messages("u1", cid)[1]
    assert wizard["status"] == "done" and wizard["revision"] == 1


def test_express_conversations_take_no_follow_up_messages(service, gen):
    gen.queue({"seeing": "Kallax", "lines": LINES})
    _, first = _call("POST", "/conversations", {"type": "express", "text": "Kallax $180"})
    status, body = _call("POST", f"/conversations/{first['conversation_id']}/messages", {"text": "hi"})
    assert status == 400 and "redo" in body["error"]["message"]


# ── metadata, reads, deletes ──────────────────────────────────────────────────


def test_patch_updates_history_metadata_only(service, store, gen):
    _, first = _start_pro()
    cid = first["conversation_id"]

    status, body = _call("PATCH", f"/conversations/{cid}",
                         {"status": "Won", "price_after": "$150", "title": " Kallax ", "message_count": 99, "bogus": 1})

    assert status == 200 and body["status"] == "won" and body["price_after"] == "$150" and body["title"] == "Kallax"
    assert store.get_conversation("u1", cid)["message_count"] == 2
    status, body = _call("PATCH", f"/conversations/{cid}", {"status": "maybe"})
    assert status == 400 and "status" in body["error"]["message"]
    status, body = _call("PATCH", f"/conversations/{cid}", {"price_after": None})
    assert status == 200 and "price_after" not in body


def test_get_and_list_return_the_documents_with_iso_dates(service, gen):
    _, first = _start_pro()
    cid = first["conversation_id"]

    status, one = _call("GET", f"/conversations/{cid}")
    assert status == 200 and one["id"] == cid and len(one["messages"]) == 2
    assert one["created_at"] == "2026-09-17T12:00:00Z"
    status, many = _call("GET", "/conversations")
    assert status == 200 and [c["id"] for c in many["conversations"]] == [cid]


def test_delete_archives_instead_of_removing(service, store, gen):
    _, first = _start_pro(images=[IMG])
    cid = first["conversation_id"]
    _start_pro()

    status, body = _call("DELETE", f"/conversations/{cid}")

    assert status == 200 and body == {"conversation_id": cid, "active": False}
    conv = store.get_conversation("u1", cid)
    assert conv["active"] is False and conv["archived_at"] == NOW
    assert len(store.list_messages("u1", cid)) == 2 and store.images  # nothing is destroyed
    assert [c["id"] for c in _call("GET", "/conversations")[1]["conversations"]] != [cid]
    assert cid not in [c["id"] for c in store.list_conversations("u1")]
    # archived conversations are gone for the app: writes and reads answer 404
    assert _call("POST", f"/conversations/{cid}/messages", {"text": "hi"})[0] == 404
    assert _call("GET", f"/conversations/{cid}")[0] == 404
    assert _call("PATCH", f"/conversations/{cid}", {"status": "won"})[0] == 404
    # archiving twice is a no-op, unknown ids are 404
    assert _call("DELETE", f"/conversations/{cid}") == (200, {"conversation_id": cid, "active": False})
    assert _call("DELETE", "/conversations/nope")[0] == 404
    assert _call("DELETE", "/conversations")[0] == 404


# ── security & validation ─────────────────────────────────────────────────────


def test_other_users_conversations_are_invisible(service, store, gen):
    store.set_conversation("u2", "theirs", {"type": "pro", "message_count": 0})
    for method, path, body in [
        ("GET", "/conversations/theirs", None),
        ("PATCH", "/conversations/theirs", {"status": "won"}),
        ("DELETE", "/conversations/theirs", None),
        ("POST", "/conversations/theirs/messages", {"text": "hi"}),
    ]:
        status, body = _call(method, path, body)
        assert status == 404, (method, path)
    assert store.get_conversation("u2", "theirs") is not None


def test_requires_a_firebase_id_token(monkeypatch, service, store):
    monkeypatch.setattr(main, "FirebaseAuthenticator", lambda: StaticAuthenticator(None))
    status, body = _call("POST", "/conversations", {"type": "pro"})
    assert status == 401 and body["error"]["status"] == "UNAUTHENTICATED"
    assert not store.users


def test_app_check_is_enforced_when_switched_on(monkeypatch, service):
    monkeypatch.setattr(main, "FirebaseAuthenticator", lambda: StaticAuthenticator(U1, app_check_ok=False))
    status, body = _call("POST", "/conversations", {"type": "pro"})
    assert status == 401 and "App Check" in body["error"]["message"]


def test_firebase_app_check_requires_the_header_when_enabled(monkeypatch):
    monkeypatch.setenv("REQUIRE_APP_CHECK", "true")
    app = Flask(__name__)
    with (
        app.test_request_context("/", method="POST", headers={"Authorization": "Bearer x"}),
        pytest.raises(Unauthorized, match="App Check"),
    ):
        FirebaseAuthenticator().verify_app_check(request)
    monkeypatch.setenv("REQUIRE_APP_CHECK", "false")
    with app.test_request_context("/", method="POST"):
        FirebaseAuthenticator().verify_app_check(request)  # off: nothing to verify


def test_bad_bodies_are_400(service, gen):
    cases = [
        {"type": "express"},
        {"type": "pro", "text": "", "images": []},
        {"type": "pro", "images": [{"mime_type": "image/png", "data": "!!"}]},
        {"type": "pro", "images": [{"mime_type": "image/png", "data": base64.b64encode(b"\x89PNG\r\n\x1a\n" + b"0" * 64).decode()}]},
    ]
    for body in cases:
        status, response = _call("POST", "/conversations", body, profile=False)
        assert status == 400, body
        assert response["error"]["status"] == "INVALID_ARGUMENT"
    assert not gen.calls


def test_unknown_routes_and_methods(service):
    status, body = _call("POST", "/conversations/abc/nope", {})
    assert status == 404 and body["error"]["status"] == "NOT_FOUND"
    status, body = _call("PUT", "/conversations")
    assert status == 405 and body["error"]["status"] == "METHOD_NOT_ALLOWED"
    assert _call("GET", "/conversations/abc/messages")[0] == 404


def test_the_turn_is_queued_and_the_response_does_not_wait_for_the_model(monkeypatch, store, gen):
    queued: list[GenerationTask] = []

    class Recorder:
        def dispatch(self, task):
            queued.append(task)

    svc = _service(store, gen, Recorder(), monkeypatch=monkeypatch)
    gen.queue({"reply": "Open at $140."})

    status, body = _start_pro()

    assert status == 200 and set(body) == {"conversation_id", "message_id", "reply_id"}
    assert gen.calls == []  # the HTTP request never touched the model
    cid = body["conversation_id"]
    wizard = _message(store, cid, body["reply_id"])
    assert wizard["status"] == "pending"
    assert store.get_conversation("u1", cid)["active_turn"]["message_id"] == wizard["id"]

    task = queued[0]
    assert (task.uid, task.conversation_id, task.message_id) == ("u1", cid, wizard["id"])
    assert (task.action, task.kind, task.profile.vibe) == ("reply", "pro", "no_nonsense")

    svc.generate(task.model_dump(mode="json"))

    wizard = _message(store, cid, wizard["id"])
    assert wizard["status"] == "done" and wizard["text"] == "Open at $140."
    assert "active_turn" not in store.get_conversation("u1", cid)


def test_only_the_last_attempt_records_a_failure(monkeypatch, store, gen):
    queued: list[GenerationTask] = []

    class Recorder:
        def dispatch(self, task):
            queued.append(task)

    svc = _service(store, gen, Recorder(), monkeypatch=monkeypatch)
    gen.queue(UpstreamError("boom"), UpstreamError("boom"), {"reply": "Third time lucky."})
    _start_pro()
    payload = queued[0].model_dump(mode="json")
    cid, mid = queued[0].conversation_id, queued[0].message_id

    with pytest.raises(UpstreamError):
        svc.generate(payload, attempt=0)  # the queue will retry: nothing is shown to the user
    assert _message(store, cid, mid)["status"] == "pending"
    assert store.get_conversation("u1", cid)["active_turn"]

    with pytest.raises(UpstreamError):
        svc.generate(payload, attempt=2)  # last attempt
    failed = _message(store, cid, mid)
    assert failed["status"] == "failed" and failed["error"]["code"] == "UPSTREAM_ERROR"
    assert "active_turn" not in store.get_conversation("u1", cid)


def test_generation_for_a_deleted_conversation_is_dropped(monkeypatch, store, gen):
    queued: list[GenerationTask] = []

    class Recorder:
        def dispatch(self, task):
            queued.append(task)

    svc = _service(store, gen, Recorder(), monkeypatch=monkeypatch)
    _start_pro()
    payload = queued[0].model_dump(mode="json")
    store.users["u1"].clear()

    svc.generate(payload)  # no exception, no retry storm

    assert gen.calls == []


def test_the_first_turn_opens_the_conversation(service, store, gen):
    gen.queue({"reply": "Open at $140."})
    status, body = _call("POST", "/conversations", {"type": "pro", "images": [IMG], "vibe": "friendly"})
    assert status == 200 and set(body) == {"conversation_id", "message_id", "reply_id"}
    conv = store.get_conversation("u1", body["conversation_id"])
    assert conv["message_count"] == 2 and conv["title"] == "Screenshot deal" and conv["preview"] == "Open at $140."
