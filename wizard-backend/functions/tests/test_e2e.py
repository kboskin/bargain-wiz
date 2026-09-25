"""End to end through the emulator suite: the functions as deployed code, on the Firestore,
Storage, Auth and Cloud Tasks emulators, answered by the model `functions/.env.local` names
(a local Ollama model). What these prove that the in-memory tests cannot: the async Firestore
client, its transaction, the Storage upload, the queue hand-off to `generate`, and the
documents as the app's listener would find them.

Opt-in, because they drive the suite you run and each call waits for a real model:

    E2E=1 venv/bin/python -m pytest tests/test_e2e.py -rs

Restart the emulators after changing backend code: the Python functions are loaded once, when
the suite starts. Every run signs up a fresh anonymous user, so what it writes stays under
that uid.
"""

import base64
import io
import os

import httpx
import pytest
from PIL import Image as PilImage
from PIL import ImageDraw

from support.emulator import EmulatorSuite, EmulatorUser

pytestmark = pytest.mark.skipif(
    not os.environ.get("E2E"),
    reason="end to end: set E2E=1 with the emulator suite running (local-stack skill)",
)

USAGE_FIELDS = {"prompt_tokens", "cached_tokens", "output_tokens", "thought_tokens"}
INTENTS = {"opener", "counter", "close"}
PROFILE = {
    "answers": [
        {"key": "vibe", "value": "friendly", "prompt": "Tone: friendly and warm."},
        {"key": "push", "value": 60, "prompt": "Push level: Balanced — a fair anchor."},
    ],
    "locale": "en",
}


def _screenshot(text: str) -> dict:
    """A small listing screenshot with readable text, as the app would send it."""
    image = PilImage.new("RGB", (480, 160), "white")
    ImageDraw.Draw(image).text((16, 64), text, fill="black")
    buf = io.BytesIO()
    image.save(buf, format="JPEG", quality=85)
    return {"mime_type": "image/jpeg", "data": base64.b64encode(buf.getvalue()).decode()}


def _assert_usage(usage: dict) -> None:
    assert set(usage) == USAGE_FIELDS
    assert usage["prompt_tokens"] > 0 and usage["output_tokens"] > 0


def _assert_lines(lines: list[dict]) -> None:
    assert 1 <= len(lines) <= 3
    assert all(line["intent"] in INTENTS and line["text"].strip() for line in lines)


@pytest.fixture(scope="module")
def user():
    suite = EmulatorSuite.from_env()
    with httpx.Client(timeout=suite.timeout_sec + 30) as http:
        try:
            yield EmulatorUser.sign_up(suite, http)
        except httpx.ConnectError as exc:
            pytest.fail(f"the emulator suite is not reachable at {suite.host}: {exc}")


def test_the_lines_tab_is_served(user):
    response = user.call("GET", "lines_that_land")

    assert response.status_code == 200, response.text
    body = response.json()
    assert body["categories"] and body["source"] in {"generated", "fallback"}


def test_the_profile_round_trips(user):
    patched = user.call(
        "PATCH", "profile", body={"preferences": {"vibe": "friendly"}, "app": {"platform": "e2e"}}
    )

    assert patched.status_code == 200, patched.text
    read = user.call("GET", "profile")
    assert read.status_code == 200, read.text
    document = read.json()
    assert document["identity"]["uid"] == user.uid
    assert document["preferences"]["vibe"] == "friendly" and document["app"]["platform"] == "e2e"


def test_a_pro_deal_end_to_end(user):
    created = user.call(
        "POST",
        "conversations",
        body={
            "type": "pro",
            "text": "They ask $180 for the Kallax shelf. What do I say?",
            "images": [_screenshot("IKEA Kallax shelf - $180 - listed 9 days ago")],
            "profile": PROFILE,
        },
    )
    assert created.status_code == 200, created.text
    ids = created.json()
    cid, rid = ids["conversation_id"], ids["reply_id"]

    # The transaction guards the turn: while the wizard is typing, a second turn is refused.
    # (Only observable with the Cloud Tasks emulator up; without it the POST waited.)
    if user.message(user.conversation(cid), rid)["status"] == "pending":
        busy = user.call(
            "POST", "conversations", f"/conversations/{cid}/messages", {"text": "Hello?"}
        )
        assert busy.status_code == 409, busy.text

    done = user.wait_for(
        cid, lambda c: user.message(c, rid)["status"] == "done", "the wizard's reply"
    )
    reply = user.message(done, rid)
    assert reply["text"].strip() and reply["model"] and reply["latency_ms"] > 0
    _assert_usage(reply["usage"])
    assert "active_turn" not in done and done["preview"]
    turn = user.message(done, ids["message_id"])
    [ref] = turn["images"]
    assert ref["path"].startswith(f"users/{user.uid}/conversations/{cid}/")
    assert ref["mime_type"] == "image/jpeg" and ref["bytes"] > 0

    options = user.call(
        "POST", "conversations", f"/conversations/{cid}/options", {"profile": PROFILE}
    )
    assert options.status_code == 200, options.text
    with_lines = user.wait_for(
        cid,
        lambda c: "lines" in user.message(c, rid) and "pending_options" not in user.message(c, rid),
        "three options",
    )
    wizard = user.message(with_lines, rid)
    _assert_lines(wizard["lines"])
    _assert_usage(wizard["options_usage"])
    assert wizard["usage"] == reply["usage"]  # the reply's own call is left alone

    redo = user.call("POST", "conversations", f"/conversations/{cid}/redo", {"profile": PROFILE})
    assert redo.status_code == 200, redo.text
    redone = user.wait_for(
        cid,
        lambda c: (
            user.message(c, rid)["revision"] == 1 and user.message(c, rid)["status"] == "done"
        ),
        "the regenerated reply",
    )
    wizard = user.message(redone, rid)
    assert "lines" not in wizard and "options_usage" not in wizard
    _assert_usage(wizard["usage"])

    follow_up = user.call(
        "POST",
        "conversations",
        f"/conversations/{cid}/messages",
        {"text": "He said $160 is his lowest.", "profile": PROFILE},
    )
    assert follow_up.status_code == 200, follow_up.text
    second = follow_up.json()["reply_id"]
    answered = user.wait_for(
        cid, lambda c: user.message(c, second)["status"] == "done", "the second reply"
    )
    assert answered["message_count"] == 4
    assert [m["seq"] for m in answered["messages"]] == [0, 1, 2, 3, 4]  # system record first


def test_an_express_deal_end_to_end(user):
    created = user.call(
        "POST",
        "conversations",
        body={
            "type": "express",
            "text": "Kallax shelf, asking $180",
            "keyword": "scuff",
            "images": [_screenshot("IKEA Kallax - $180"), _screenshot("Small scuff on the side")],
            "profile": PROFILE,
        },
    )
    assert created.status_code == 200, created.text
    ids = created.json()
    cid, rid = ids["conversation_id"], ids["reply_id"]

    done = user.wait_for(cid, lambda c: "express" in c, "the Express answer")

    express = done["express"]
    assert express["seeing"].strip() and express["keyword"] == "scuff"
    _assert_lines(express["lines"])
    turn = user.message(done, ids["message_id"])
    assert [ref["path"] for ref in express["images"]] == [ref["path"] for ref in turn["images"]]
    wizard = user.message(done, rid)
    assert wizard["lines"] == express["lines"] and wizard["seeing"] == express["seeing"]
    _assert_usage(wizard["usage"])
    assert done["title"] and "active_turn" not in done

    follow_up = user.call(
        "POST", "conversations", f"/conversations/{cid}/messages", {"text": "and?"}
    )
    assert follow_up.status_code == 400  # Express deals take no follow-up messages


def test_the_history_list_edits_and_archives(user):
    created = user.call(
        "POST",
        "conversations",
        body={"type": "pro", "text": "Bike, $300, worth it?", "profile": PROFILE},
    )
    assert created.status_code == 200, created.text
    cid = created.json()["conversation_id"]

    listed = user.call("GET", "conversations", "/conversations").json()["conversations"]
    assert cid in [c["id"] for c in listed]

    edited = user.call(
        "PATCH", "conversations", f"/conversations/{cid}", {"title": "E2E bike", "status": "won"}
    )
    assert edited.status_code == 200, edited.text
    assert (edited.json()["title"], edited.json()["status"]) == ("E2E bike", "won")

    archived = user.call("DELETE", "conversations", f"/conversations/{cid}")
    assert archived.status_code == 200 and archived.json()["active"] is False
    listed = user.call("GET", "conversations", "/conversations").json()["conversations"]
    assert cid not in [c["id"] for c in listed]
    assert user.call("GET", "conversations", f"/conversations/{cid}").status_code == 404
