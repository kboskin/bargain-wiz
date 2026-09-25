"""HTTP-level tests for the `conversations` function, against an in-memory store.

Most tests queue the generation instead of running it ([app]): they are about what is stored,
routed and refused, and about exactly what the worker would ask the model — checked on the
prompt it builds. Tests about what comes back run the worker against the local model
([inline] + `local_model`), or against a closed port to see a failure (`unreachable_model`).
"""

import asyncio
import base64
import io
from datetime import UTC, datetime

import pytest
from flask import Flask, request
from PIL import Image as PilImage

import main
from container import Container
from core.ai import ImagePart, Prompt, TokenUsage
from core.auth.firebase import AuthInfo, FirebaseAuthenticator
from core.config import ConversationSettings, SecuritySettings
from core.errors import Unauthorized, UpstreamError
from core.firestore import FieldOp, FirestorePatch
from core.observability import GenerationRun, ModelCall
from features.conversations.domain.documents import ConversationPatches, Summaries
from features.conversations.domain.models import GenerationTask
from features.negotiation.domain.models import ExpressRequest
from support import (
    FixedClock,
    InMemoryConversationStore,
    InMemoryMetrics,
    InMemoryScreenshotStore,
    StaticAuthenticator,
    call,
    install,
)

NOW = datetime(2026, 9, 17, 12, tzinfo=UTC)
U1 = AuthInfo(uid="u1", provider="anonymous")
INTENTS = {"opener", "counter", "close"}


def _png(width=40, height=30) -> str:
    buf = io.BytesIO()
    PilImage.new("RGB", (width, height), "blue").save(buf, format="PNG")
    return base64.b64encode(buf.getvalue()).decode()


PNG = _png()
IMG = {"mime_type": "image/png", "data": PNG}


class Recorder:
    """Keeps the tasks a write dispatched instead of running them."""

    def __init__(self):
        self.tasks: list[GenerationTask] = []

    async def dispatch(self, task: GenerationTask) -> None:
        self.tasks.append(task)


@pytest.fixture
def store() -> InMemoryConversationStore:
    return InMemoryConversationStore(FixedClock(NOW))


@pytest.fixture
def screenshots() -> InMemoryScreenshotStore:
    return InMemoryScreenshotStore()


@pytest.fixture
def queue() -> Recorder:
    return Recorder()


@pytest.fixture
def metrics() -> InMemoryMetrics:
    return InMemoryMetrics()


def _parts(store, screenshots, metrics) -> dict:
    return {
        "conversation_store": store,
        "screenshot_store": screenshots,
        "authenticator": StaticAuthenticator(U1),
        "metrics": metrics,
    }


@pytest.fixture
def app(monkeypatch, store, screenshots, queue, metrics) -> Container:
    """Writes are stored and their generation queued, never run: no model is asked."""
    return install(monkeypatch, dispatcher=queue, **_parts(store, screenshots, metrics))


@pytest.fixture
def inline(monkeypatch, store, screenshots, metrics) -> Container:
    """Every write runs its generation in the request, as the emulator does without a tasks
    queue — so the model named by AI_MODEL answers before the response returns."""
    return install(monkeypatch, inline_generation=True, **_parts(store, screenshots, metrics))


# Every write carries the buyer's profile, exactly as the app sends it. What each tone means
# is the template's to say, and the app forwards it with every request (AI_INTEGRATION.md).
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


def _call(method, path, body=None, profile=True):
    if profile and isinstance(body, dict):
        # `vibe` and `locale` are written flat by the callers below for brevity; the wire
        # nests them, and a conversation-scoped answer also rides as an override.
        body = dict(body)
        vibe, locale = body.pop("vibe", "friendly"), body.pop("locale", "en")
        body = {"profile": _profile(vibe, locale), "overrides": {"vibe": vibe}, **body}
    status, response, _ = call(main.conversations, method, path, body)
    return status, response


def _start_pro(text="They ask $180 for the Kallax", images=None, **profile):
    return _call(
        "POST",
        "/conversations",
        {
            "type": "pro",
            "text": text,
            "images": images or [],
            "vibe": "no_nonsense",
            "locale": "en",
            **profile,
        },
    )


def _turns(store, cid, uid="u1"):
    """The conversation's turns. `create` also writes the `system` record at seq 0 — the
    configuration the chat started with, which the app skips too (CONVERSATIONS.md)."""
    return [m for m in store.messages(uid, cid) if m["role"] != "system"]


def _message(store, cid, mid):
    return next(m for m in store.messages("u1", cid) if m["id"] == mid)


def _prompt(app: Container, task: GenerationTask) -> Prompt:
    """Exactly what the worker would send the model for [task]."""
    job = asyncio.run(app.conversations.worker.job(task))
    prompts = app.negotiation.prompts
    return (
        prompts.express(job.request)
        if isinstance(job.request, ExpressRequest)
        else prompts.pro(job.request)
    )


def _reply_lands(store, cid, rid, text="Open at $140."):
    """The state a finished generation leaves behind, for tests about the step after it."""
    store.seed_message("u1", cid, rid, {"status": "done", "text": text}, merge=True)
    store.seed_conversation("u1", cid, {"active_turn": FieldOp.DELETE}, merge=True)


def _assert_usage(usage):
    """Token counts as the local model reports them: Ollama has no cache or thinking counts."""
    assert set(usage) == {"prompt_tokens", "cached_tokens", "output_tokens", "thought_tokens"}
    assert usage["prompt_tokens"] > 0 and usage["output_tokens"] > 0


def _assert_lines(lines):
    assert 1 <= len(lines) <= 3
    assert all(line["intent"] in INTENTS and line["text"].strip() for line in lines)


# ── pro chat ──────────────────────────────────────────────────────────────────


def test_first_turn_stores_the_user_turn_the_placeholder_and_the_screenshot(
    app, store, screenshots, queue
):
    status, body = _start_pro(images=[IMG])

    assert status == 200
    cid, mid, rid = body["conversation_id"], body["message_id"], body["reply_id"]
    conv = store.conversation("u1", cid)
    assert conv["type"] == "pro" and conv["status"] == "open"
    assert conv["overrides"] == {
        "vibe": "no_nonsense"
    }  # the deal remembers the tone it was opened with
    assert conv["active"] is True
    assert conv["message_count"] == 2 and conv["active_turn"]["message_id"] == rid
    assert conv["title"] == "They ask $180 for the Kallax"
    assert (
        conv["preview"] == "They ask $180 for the Kallax"
    )  # the buyer's words until the wizard answers
    assert conv["thumbnail"]["path"].startswith(f"users/u1/conversations/{cid}/")
    assert conv["created_at"] == NOW and conv["last_message_at"] == NOW

    user, wizard = _turns(store, cid)
    assert (user["id"], wizard["id"]) == (mid, rid)
    assert user["role"] == "user" and user["seq"] == 1 and user["status"] == "done"
    assert user["reply_id"] == rid
    ref = user["images"][0]
    assert ref["mime_type"] == "image/jpeg" and ref["width"] == 40 and ref["height"] == 30
    assert screenshots.get(ref["path"])[:3] == b"\xff\xd8\xff"  # re-encoded as JPEG, no PNG left
    assert wizard["role"] == "model" and wizard["seq"] == 2 and wizard["status"] == "pending"
    assert wizard["text"] == "" and wizard["revision"] == 0

    [task] = queue.tasks
    assert (task.message_id, task.kind, task.action) == (rid, "pro", "reply")


def test_the_first_turn_asks_about_the_stored_screenshot_by_uri(app, store, queue):
    """The model is handed the object's URI, not its bytes: the worker never downloads what it
    just uploaded, and a later turn re-references the same screenshot for free."""
    _, body = _start_pro(images=[IMG])
    ref = _turns(store, body["conversation_id"])[0]["images"][0]

    prompt = _prompt(app, queue.tasks[0])

    assert "No-Nonsense" in prompt.system
    assert prompt.parts[0] == ImagePart(mime_type="image/jpeg", uri=f"gs://in-memory/{ref['path']}")
    assert "Buyer: They ask $180 for the Kallax (screenshot attached)" in prompt.parts[-1].text


def test_the_local_model_completes_the_reply(inline, store, metrics, local_model):
    status, body = _start_pro(images=[IMG])

    assert status == 200
    cid, rid = body["conversation_id"], body["reply_id"]
    wizard = _message(store, cid, rid)
    assert wizard["status"] == "done" and wizard["text"].strip()
    assert wizard["model"] == local_model and wizard["revision"] == 0 and "latency_ms" in wizard
    _assert_usage(wizard["usage"])
    [call] = metrics.of(ModelCall)  # what the message records is what the call measured
    assert (wizard["usage"]["prompt_tokens"], wizard["usage"]["output_tokens"]) == (
        call.prompt_tokens,
        call.output_tokens,
    )
    conv = store.conversation("u1", cid)
    assert "active_turn" not in conv
    assert conv["preview"] == Summaries(ConversationSettings.current()).preview(wizard["text"])
    [generation] = metrics.of(GenerationRun)
    assert (generation.kind, generation.action, generation.outcome, generation.final) == (
        "pro",
        "reply",
        "ok",
        True,
    )
    assert metrics.of(ModelCall)[0].images == 1  # the stored screenshot reached the local model


def test_a_follow_up_is_asked_about_with_the_stored_history(app, store, queue):
    _, first = _start_pro(images=[IMG])
    cid = first["conversation_id"]
    _reply_lands(store, cid, first["reply_id"], "Open at $140.")

    status, body = _call(
        "POST",
        f"/conversations/{cid}/messages",
        {"text": "Seller says $170 is final", "vibe": "tactical"},
    )

    assert status == 200 and body["conversation_id"] == cid
    assert [m["seq"] for m in _turns(store, cid)] == [1, 2, 3, 4]
    prompt = _prompt(app, queue.tasks[1])
    transcript = prompt.parts[-1].text
    assert (
        "Wizard: Open at $140." in transcript and "Buyer: Seller says $170 is final" in transcript
    )
    assert prompt.parts[0].type == "image"  # the stored screenshot is reused
    assert "Tactical" in prompt.system
    assert store.conversation("u1", cid)["overrides"] == {"vibe": "tactical"}


def test_a_second_options_request_while_one_is_pending_does_not_queue_another(app, store, queue):
    """No client key dedupes writes: `pending_options` on the message is the guard, and it
    survives an app restart in a way a per-process id never did."""
    _, first = _start_pro()
    cid, rid = first["conversation_id"], first["reply_id"]
    _reply_lands(store, cid, rid)
    store.seed_message("u1", cid, rid, {"pending_options": True}, merge=True)

    status, body = _call("POST", f"/conversations/{cid}/options", {})

    assert status == 200 and body["message_id"] == rid
    assert len(queue.tasks) == 1  # still just the reply


def test_options_wait_for_the_reply(app, store):
    _, first = _start_pro()
    status, body = _call("POST", f"/conversations/{first['conversation_id']}/options", {})
    assert status == 400 and "Wait" in body["error"]["message"]


def test_options_are_asked_about_the_reply_itself(app, store, queue):
    _, first = _start_pro()
    cid, rid = first["conversation_id"], first["reply_id"]
    _reply_lands(store, cid, rid, "Open at $140.")

    status, body = _call("POST", f"/conversations/{cid}/options", {"vibe": "friendly"})

    assert status == 200 and body["message_id"] == rid
    assert _message(store, cid, rid)["pending_options"] is True  # the spinner the app trusts
    task = queue.tasks[1]
    assert (task.action, task.message_id) == ("options", rid)
    prompt = _prompt(app, task)
    assert (
        "Wizard: Open at $140." in prompt.parts[-1].text
    )  # options include the reply they are for
    assert "three ready-to-paste lines" in prompt.parts[-1].text


def test_the_local_model_attaches_options_to_the_reply(inline, store, local_model):
    _, first = _start_pro()
    cid, rid = first["conversation_id"], first["reply_id"]

    status, _ = _call("POST", f"/conversations/{cid}/options", {"vibe": "friendly"})

    assert status == 200
    wizard = _message(store, cid, rid)
    _assert_lines(wizard["lines"])
    assert "pending_options" not in wizard  # the spinner is cleared when the lines land
    _assert_usage(wizard["options_usage"])  # beside the reply's own `usage`, not over it
    _assert_usage(wizard["usage"])
    assert wizard["options_usage"] != wizard["usage"]


def test_sending_while_the_wizard_is_typing_is_rejected(app, store):
    _, first = _start_pro()  # queued, so the wizard is still typing

    status, body = _call(
        "POST", f"/conversations/{first['conversation_id']}/messages", {"text": "hi"}
    )

    assert status == 409 and body["error"]["status"] == "TURN_IN_PROGRESS"


@pytest.mark.usefixtures("unreachable_model")
def test_a_failed_generation_marks_the_reply_failed_and_frees_the_conversation(
    inline, store, metrics
):
    status, body = _start_pro()
    # The turn was accepted; the failure reaches the app through the listener, not the response.
    assert status == 200

    cid = body["conversation_id"]
    assert "active_turn" not in store.conversation("u1", cid)
    wizard = _turns(store, cid)[1]
    assert wizard["status"] == "failed" and wizard["error"]["code"] == "UPSTREAM_ERROR"
    assert metrics.of(GenerationRun)[0].outcome == "call_failed"

    status, _ = _call("POST", f"/conversations/{cid}/messages", {"text": "retry"})
    assert status == 200  # the conversation is not stuck


def test_the_answer_records_the_usage_its_call_reported_and_clears_unreported_usage():
    usage = TokenUsage(
        prompt_tokens=5160, cached_tokens=3360, output_tokens=210, thought_tokens=480
    )

    reported = ConversationPatches.answered({"text": "Hi"}, model="m", latency_ms=9, usage=usage)
    unreported = ConversationPatches.answered({"text": "Hi"}, model="m", latency_ms=9, usage=None)

    assert reported["usage"] is usage  # the patch carries the model; the store makes it plain
    assert FirestorePatch.plain(reported)["usage"] == {
        "prompt_tokens": 5160,
        "cached_tokens": 3360,
        "output_tokens": 210,
        "thought_tokens": 480,
    }
    # a redo whose call reported nothing must not keep the replaced revision's counts
    assert unreported["usage"] is FieldOp.DELETE
    assert ConversationPatches.options_answered([], usage=None)["options_usage"] is FieldOp.DELETE


def test_redo_regenerates_in_place_and_clears_options(app, store, queue):
    _, first = _start_pro()
    cid, rid = first["conversation_id"], first["reply_id"]
    _reply_lands(store, cid, rid)
    options = {"lines": [{"intent": "opener", "text": "Hi", "why": None}], "options_usage": {}}
    store.seed_message("u1", cid, rid, options, merge=True)

    status, body = _call("POST", f"/conversations/{cid}/redo", {"vibe": "quiet_closer"})

    assert status == 200 and body["message_id"] == rid
    wizard = _message(store, cid, rid)
    assert wizard["status"] == "pending" and wizard["revision"] == 1
    assert "lines" not in wizard and "options_usage" not in wizard
    assert store.conversation("u1", cid)["active_turn"]["message_id"] == rid
    prompt = _prompt(app, queue.tasks[-1])
    assert "different angle" in prompt.parts[-1].text and "Quiet" in prompt.system


def test_the_local_model_regenerates_a_reply_in_place(inline, store, local_model):
    _, first = _start_pro()
    cid, rid = first["conversation_id"], first["reply_id"]

    status, _ = _call("POST", f"/conversations/{cid}/redo", {"vibe": "quiet_closer"})

    assert status == 200
    wizard = _message(store, cid, rid)
    assert wizard["status"] == "done" and wizard["revision"] == 1 and wizard["text"].strip()
    _assert_usage(wizard["usage"])  # the new revision's call
    assert "active_turn" not in store.conversation("u1", cid)


# ── express ───────────────────────────────────────────────────────────────────


def _start_express(**body):
    return _call("POST", "/conversations", {"type": "express", **body})


def test_an_express_deal_is_asked_about_every_screenshot(app, store, queue):
    status, body = _start_express(keyword="scuff", vibe="tactical", locale="es", images=[IMG, IMG])

    assert status == 200
    assert set(body) == {
        "conversation_id",
        "message_id",
        "reply_id",
    }  # the result arrives via the listener
    conv = store.conversation("u1", body["conversation_id"])
    assert conv["type"] == "express" and conv["keyword"] == "scuff"
    prompt = _prompt(app, queue.tasks[0])
    assert len(prompt.images) == 2 and "focus on: scuff" in prompt.parts[-1].text
    assert "locale tag es" in prompt.system


def test_the_local_model_answers_an_express_deal(inline, store, local_model):
    status, body = _start_express(
        keyword="scuff", text="IKEA Kallax, asking $180", images=[IMG, IMG]
    )

    assert status == 200
    cid = body["conversation_id"]
    conv = store.conversation("u1", cid)
    express = conv["express"]
    assert express["seeing"].strip() and express["keyword"] == "scuff"
    _assert_lines(express["lines"])
    assert conv["title"] == Summaries(ConversationSettings.current()).title(
        seeing=express["seeing"], has_images=True
    )
    user, wizard = _turns(store, cid)
    assert [ref["path"] for ref in express["images"]] == [ref["path"] for ref in user["images"]]
    assert wizard["seeing"] == express["seeing"] and wizard["lines"] == express["lines"]
    assert wizard["model"] == local_model
    _assert_usage(wizard["usage"])
    assert (
        "usage" not in express
    )  # the deal's answer, as the Express flow reads it, stays as it was


def test_express_redo_asks_with_the_new_tone_and_keyword(app, store, queue):
    _, first = _start_express(images=[IMG])
    cid = first["conversation_id"]
    _reply_lands(store, cid, first["reply_id"], "Kallax")

    status, _ = _call(
        "POST", f"/conversations/{cid}/redo", {"vibe": "friendly", "keyword": "pickup"}
    )

    assert status == 200
    conv = store.conversation("u1", cid)
    assert conv["overrides"] == {"vibe": "friendly"} and conv["keyword"] == "pickup"
    prompt = _prompt(app, queue.tasks[-1])
    assert "Friendly" in prompt.system and "focus on: pickup" in prompt.parts[-1].text
    assert _turns(store, cid)[1]["revision"] == 1


@pytest.mark.usefixtures("unreachable_model")
def test_express_redo_after_a_failed_generation_reuses_the_stored_screenshots(app, store, queue):
    """What the app's Retry does: the failed deal is regenerated in place, so a turn that broke
    never costs a second conversation."""
    _, first = _start_express(keyword="scuff", images=[IMG])
    cid = first["conversation_id"]
    with pytest.raises(UpstreamError):
        asyncio.run(
            app.conversations.worker.run(queue.tasks[0].model_dump(mode="json"), attempt=2)
        )  # the last attempt fails
    failed = store.conversation("u1", cid)
    assert failed["last_error"]["code"] == "UPSTREAM_ERROR" and "active_turn" not in failed

    status, body = _call("POST", f"/conversations/{cid}/redo", {"vibe": "friendly"})

    assert status == 200 and body["conversation_id"] == cid
    assert len(store.conversations("u1")) == 1
    prompt = _prompt(app, queue.tasks[-1])
    # The screenshot travelled once: the regeneration reads it back from the stored turn.
    assert len(prompt.images) == 1 and prompt.images[0].uri.startswith("gs://in-memory/")
    assert "focus on: scuff" in prompt.parts[-1].text  # kept: the retry carries no new keyword
    assert _turns(store, cid)[1]["revision"] == 1


def test_express_conversations_take_no_follow_up_messages(app):
    _, first = _start_express(text="Kallax $180")
    status, body = _call(
        "POST", f"/conversations/{first['conversation_id']}/messages", {"text": "hi"}
    )
    assert status == 400 and "redo" in body["error"]["message"]


# ── metadata, reads, deletes ──────────────────────────────────────────────────


def test_patch_updates_history_metadata_only(app, store):
    _, first = _start_pro()
    cid = first["conversation_id"]

    status, body = _call(
        "PATCH",
        f"/conversations/{cid}",
        {
            "status": "Won",
            "price_after": "$150",
            "title": " Kallax ",
            "message_count": 99,
            "bogus": 1,
        },
    )

    assert (
        status == 200
        and body["status"] == "won"
        and body["price_after"] == "$150"
        and body["title"] == "Kallax"
    )
    assert store.conversation("u1", cid)["message_count"] == 2
    status, body = _call("PATCH", f"/conversations/{cid}", {"status": "maybe"})
    assert status == 400 and "status" in body["error"]["message"]
    status, body = _call("PATCH", f"/conversations/{cid}", {"price_after": None})
    assert status == 200 and "price_after" not in body


def test_get_and_list_return_the_documents_with_iso_dates(app):
    _, first = _start_pro()
    cid = first["conversation_id"]

    status, one = _call("GET", f"/conversations/{cid}")
    # The whole transcript, configuration included: system at seq 0, then the turns. The app
    # skips the system row; the endpoint does not hide it, so a deal can be read back exactly
    # as the model saw it.
    assert status == 200 and one["id"] == cid
    assert [m["role"] for m in one["messages"]] == ["system", "user", "model"]
    assert one["messages"][0]["seq"] == 0
    assert one["messages"][0]["text"].startswith("You are Bargain Wiz")
    assert one["created_at"] == "2026-09-17T12:00:00Z"
    status, many = _call("GET", "/conversations")
    assert status == 200 and [c["id"] for c in many["conversations"]] == [cid]


def test_delete_archives_instead_of_removing(app, store, screenshots):
    _, first = _start_pro(images=[IMG])
    cid = first["conversation_id"]
    _start_pro()

    status, body = _call("DELETE", f"/conversations/{cid}")

    assert status == 200 and body == {"conversation_id": cid, "active": False}
    conv = store.conversation("u1", cid)
    assert conv["active"] is False and conv["archived_at"] == NOW
    assert len(_turns(store, cid)) == 2 and screenshots.images  # nothing is destroyed
    assert cid not in [c["id"] for c in _call("GET", "/conversations")[1]["conversations"]]
    assert cid not in [c["id"] for c in store.conversations("u1")]
    # archived conversations are gone for the app: writes and reads answer 404
    assert _call("POST", f"/conversations/{cid}/messages", {"text": "hi"})[0] == 404
    assert _call("GET", f"/conversations/{cid}")[0] == 404
    assert _call("PATCH", f"/conversations/{cid}", {"status": "won"})[0] == 404
    # archiving twice is a no-op, unknown ids are 404
    assert _call("DELETE", f"/conversations/{cid}") == (
        200,
        {"conversation_id": cid, "active": False},
    )
    assert _call("DELETE", "/conversations/nope")[0] == 404
    assert _call("DELETE", "/conversations")[0] == 404


# ── security & validation ─────────────────────────────────────────────────────


def test_other_users_conversations_are_invisible(app, store):
    store.seed_conversation("u2", "theirs", {"type": "pro", "message_count": 0})
    for method, path, body in [
        ("GET", "/conversations/theirs", None),
        ("PATCH", "/conversations/theirs", {"status": "won"}),
        ("DELETE", "/conversations/theirs", None),
        ("POST", "/conversations/theirs/messages", {"text": "hi"}),
    ]:
        status, _ = _call(method, path, body)
        assert status == 404, (method, path)
    assert store.conversation("u2", "theirs") is not None


def test_requires_a_firebase_id_token(monkeypatch, store):
    install(
        monkeypatch,
        conversation_store=store,
        authenticator=StaticAuthenticator(None),
        dispatcher=Recorder(),
    )
    status, body = _call("POST", "/conversations", {"type": "pro"})
    assert status == 401 and body["error"]["status"] == "UNAUTHENTICATED"
    assert not store.users


def test_app_check_is_enforced_when_switched_on(monkeypatch, store):
    install(
        monkeypatch,
        conversation_store=store,
        authenticator=StaticAuthenticator(U1, app_check_ok=False),
    )
    status, body = _call("POST", "/conversations", {"type": "pro"})
    assert status == 401 and "App Check" in body["error"]["message"]


def test_firebase_app_check_requires_the_header_when_enabled():
    enforced = FirebaseAuthenticator(SecuritySettings(require_app_check=True))
    with (
        Flask(__name__).test_request_context(
            "/", method="POST", headers={"Authorization": "Bearer x"}
        ),
        pytest.raises(Unauthorized, match="App Check"),
    ):
        asyncio.run(enforced.verify_app_check(request))
    with Flask(__name__).test_request_context("/", method="POST"):
        asyncio.run(
            FirebaseAuthenticator(SecuritySettings(require_app_check=False)).verify_app_check(
                request
            )
        )  # off: nothing to verify


def test_bad_bodies_are_400(app, queue):
    cases = [
        {"type": "express"},
        {"type": "pro", "text": "", "images": []},
        {"type": "pro", "images": [{"mime_type": "image/png", "data": "!!"}]},
        {
            "type": "pro",
            "images": [
                {
                    "mime_type": "image/png",
                    "data": base64.b64encode(b"\x89PNG\r\n\x1a\n" + b"0" * 64).decode(),
                }
            ],
        },
    ]
    for body in cases:
        status, response = _call("POST", "/conversations", body, profile=False)
        assert status == 400, body
        assert response["error"]["status"] == "INVALID_ARGUMENT"
    assert not queue.tasks


def test_unknown_routes_and_methods(app):
    status, body = _call("POST", "/conversations/abc/nope", {})
    assert status == 404 and body["error"]["status"] == "NOT_FOUND"
    status, body = _call("PUT", "/conversations")
    assert status == 405 and body["error"]["status"] == "METHOD_NOT_ALLOWED"
    assert _call("GET", "/conversations/abc/messages")[0] == 404


# ── the queue and the worker ──────────────────────────────────────────────────


def test_the_turn_is_queued_and_the_response_does_not_wait_for_the_model(
    app, store, queue, metrics
):
    status, body = _start_pro()

    assert status == 200 and set(body) == {"conversation_id", "message_id", "reply_id"}
    assert metrics.of(ModelCall) == []  # the HTTP request never touched the model
    cid = body["conversation_id"]
    wizard = _message(store, cid, body["reply_id"])
    assert wizard["status"] == "pending"
    assert store.conversation("u1", cid)["active_turn"]["message_id"] == wizard["id"]

    [task] = queue.tasks
    assert (task.uid, task.conversation_id, task.message_id) == ("u1", cid, wizard["id"])
    assert (task.action, task.kind) == ("reply", "pro")
    assert next((a.key, a.value) for a in task.profile.answers) == ("vibe", "no_nonsense")


def test_the_local_model_completes_a_queued_task(app, store, queue, local_model):
    _, body = _start_pro()

    asyncio.run(app.conversations.worker.run(queue.tasks[0].model_dump(mode="json"), attempt=0))

    wizard = _message(store, body["conversation_id"], body["reply_id"])
    assert wizard["status"] == "done" and wizard["text"].strip()
    assert "active_turn" not in store.conversation("u1", body["conversation_id"])


def test_the_conversation_records_the_system_prompt_it_started_with(app, store):
    """Firestore keeps the configuration, not just the turns, so a deal can be read back as
    the model saw it — which matters now the prompt comes from Remote Config and can change
    between conversations without a deploy."""
    _, body = _start_pro(vibe="no_nonsense")
    cid = body["conversation_id"]

    system = store.messages("u1", cid)[0]
    assert (system["role"], system["seq"], system["status"]) == ("system", 0, "done")
    # Verbatim what the model was configured with, the template's own lines included.
    assert system["text"].startswith("You are Bargain Wiz")
    assert VIBE_PROMPTS["no_nonsense"] in system["text"]
    # Not a turn: it does not count against the chat's cap, and it sits before seq 1.
    assert store.conversation("u1", cid)["message_count"] == 2
    assert [m["seq"] for m in _turns(store, cid)] == [1, 2]


def test_the_system_record_is_not_replayed_as_a_chat_turn(app, store, queue):
    """It already reaches the model as the system prompt; sending it again as history would
    say everything twice."""
    _, body = _start_pro()
    cid = body["conversation_id"]
    _reply_lands(store, cid, body["reply_id"])
    _call("POST", f"/conversations/{cid}/messages", {"text": "They said no"})

    prompt = _prompt(app, queue.tasks[-1])
    assert (
        "You are Bargain Wiz" not in prompt.parts[-1].text
    )  # only in `system`, never in the material
    assert prompt.system.startswith("You are Bargain Wiz")


def test_a_later_turn_re_references_the_screenshot_without_downloading_it(
    app, store, screenshots, queue
):
    """A long chat does not re-read the same screenshots out of the bucket on every turn: the
    job carries their URIs, and only a provider that cannot read them fetches the bytes."""
    _, body = _start_pro(images=[IMG])
    cid = body["conversation_id"]
    ref = _turns(store, cid)[0]["images"][0]
    _reply_lands(store, cid, body["reply_id"])
    _call("POST", f"/conversations/{cid}/messages", {"text": "They said no"})

    downloads = []
    original_get, original_read = screenshots.get, screenshots.read
    screenshots.get = lambda path: (downloads.append(path), original_get(path))[1]
    screenshots.read = lambda uri: (downloads.append(uri), original_read(uri))[1]

    prompt = _prompt(app, queue.tasks[-1])

    assert prompt.images == [ImagePart(mime_type="image/jpeg", uri=f"gs://in-memory/{ref['path']}")]
    assert downloads == []  # building the job read no bytes


def test_the_answer_descriptions_survive_the_queue_and_reach_the_prompt(app, queue):
    """The worker prompts from the task payload, so a `prompt` sentence the client sent has to
    come back out of `model_dump(mode="json")` intact (wizard-app/AI_INTEGRATION.md)."""
    _start_pro(
        profile={
            "answers": [
                {"key": "vibe", "value": "no_nonsense", "prompt": "Bulldozer: never blinks."}
            ]
        }
    )
    task = queue.tasks[0]
    assert [(a.key, a.prompt) for a in task.profile.answers] == [
        ("vibe", "Bulldozer: never blinks.")
    ]

    delivered = GenerationTask.model_validate(task.model_dump(mode="json"))
    assert "Bulldozer: never blinks." in _prompt(app, delivered).system


@pytest.mark.usefixtures("unreachable_model")
def test_only_the_last_attempt_records_a_failure(app, store, queue, metrics):
    _start_pro()
    payload = queue.tasks[0].model_dump(mode="json")
    cid, mid = queue.tasks[0].conversation_id, queue.tasks[0].message_id

    with pytest.raises(UpstreamError):
        asyncio.run(
            app.conversations.worker.run(payload, attempt=0)
        )  # the queue will retry: nothing is shown to the user
    assert _message(store, cid, mid)["status"] == "pending"
    assert store.conversation("u1", cid)["active_turn"]

    with pytest.raises(UpstreamError):
        asyncio.run(app.conversations.worker.run(payload, attempt=2))  # last attempt
    failed = _message(store, cid, mid)
    assert failed["status"] == "failed" and failed["error"]["code"] == "UPSTREAM_ERROR"
    assert "active_turn" not in store.conversation("u1", cid)
    assert [(g.attempt, g.final, g.outcome) for g in metrics.of(GenerationRun)] == [
        (1, False, "call_failed"),
        (3, True, "call_failed"),
    ]


def test_generation_for_a_deleted_conversation_is_dropped(app, store, queue, metrics):
    _start_pro()
    payload = queue.tasks[0].model_dump(mode="json")
    store.users["u1"].clear()

    asyncio.run(app.conversations.worker.run(payload, attempt=0))  # no exception, no retry storm

    assert metrics.of(ModelCall) == []
    assert metrics.of(GenerationRun)[0].outcome == "dropped"


def test_the_first_turn_opens_the_conversation(app, store):
    status, body = _call(
        "POST", "/conversations", {"type": "pro", "images": [IMG], "vibe": "friendly"}
    )
    assert status == 200 and set(body) == {"conversation_id", "message_id", "reply_id"}
    conv = store.conversation("u1", body["conversation_id"])
    assert (
        conv["message_count"] == 2
        and conv["title"] == "Screenshot deal"
        and conv["preview"] == "Screenshot"
    )


def test_each_task_is_its_own_kind_of_generation(app):
    from features.conversations.domain.generations import (
        ExpressGeneration,
        OptionsGeneration,
        ReplyGeneration,
    )

    profile = {"answers": []}
    generations = app.conversations.generations

    def kind(**task):
        return type(
            generations.for_task(
                GenerationTask(
                    uid="u1", conversation_id="c", message_id="m", profile=profile, **task
                )
            )
        )

    assert kind() is ReplyGeneration
    assert kind(kind="express") is ExpressGeneration
    assert kind(action="options") is OptionsGeneration
    assert (
        kind(kind="express", action="options") is OptionsGeneration
    )  # options are always about a Pro reply
