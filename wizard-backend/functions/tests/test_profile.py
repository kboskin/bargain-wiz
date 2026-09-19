"""Tests for the profile endpoint and the Firestore merge rules behind it."""
import json
from datetime import UTC, datetime

import pytest
from flask import Flask, request

import main
from core.auth.firebase import AuthInfo, StaticAuthenticator
from core.errors import BadRequest, Unauthorized
from core.firestore import DELETE, SERVER_TIME
from core.serialization import jsonable
from features.profile.data.store import InMemoryProfileStore
from features.profile.domain import profile as up

NOW = datetime(2026, 9, 17, 12, 0, tzinfo=UTC)


@pytest.fixture
def store(monkeypatch):
    s = InMemoryProfileStore(clock=lambda: NOW)
    monkeypatch.setattr(main, "FirestoreProfileStore", lambda: s)
    monkeypatch.setattr(main, "FirebaseAuthenticator", main.FirebaseAuthenticator)  # _call swaps it per request
    return s


def _call(method, body=None, query="", auth: AuthInfo | None = None, invalid_token=False):
    headers = {"Authorization": "Bearer fake"} if (auth or invalid_token) else {}
    main.FirebaseAuthenticator = lambda: StaticAuthenticator(auth, invalid_token=invalid_token)
    with Flask(__name__).test_request_context(f"/profile{query}", method=method, json=body, headers=headers):
        res = main.profile(request)
    return res.status_code, json.loads(res.get_data(as_text=True))


# ── validation ────────────────────────────────────────────────────────────────


def test_build_patch_validates_and_normalises_known_sections():
    patch = up.build_patch(
        {
            "preferences": {"vibe": " Tactical ", "push": 140, "deal_size": 550, "marketplace": None,
                            "hurdles": ["Starting", "", 3, "fair_price"],
                            "experience_level": "pro", "gone": None},
            "onboarding_status": {"completed": True},
            "referral": {"code": " FRIEND-42 "},
            "app": {"platform": "android", "flavor": "dev"},
            "unknown_section": {"x": 1},
        },
        up.Identity(uid="u1"),
    )
    # Fields this backend reads are coerced; a question it has never heard of rides along as
    # sent, which is what lets a screen be added in Remote Config without a deploy.
    assert patch["preferences"] == {"vibe": "tactical", "push": 100, "deal_size": 550.0, "marketplace": DELETE,
                                    "hurdles": ["starting", "fair_price"],
                                    "experience_level": "pro", "gone": DELETE}
    assert patch["onboarding_status"] == {"completed_at": SERVER_TIME}
    assert patch["referral"] == {"code": "FRIEND-42", "entered_at": SERVER_TIME}
    assert patch["app"] == {"platform": "android", "flavor": "dev"}
    assert patch["identity"] == {"uid": "u1"}
    assert "unknown_section" not in patch and patch["schema_version"] == up.SCHEMA_VERSION


def test_build_patch_rejects_wrong_types():
    ident = up.Identity(uid="u1")
    with pytest.raises(BadRequest):
        up.build_patch({"preferences": {"push": "high"}}, ident)
    with pytest.raises(BadRequest):
        up.build_patch({"referral": "code"}, ident)


# ── merge flows ───────────────────────────────────────────────────────────────


def test_identity_without_a_uid_is_rejected():
    with pytest.raises(Unauthorized):
        up.Identity().doc_id  # noqa: B018


def test_patch_keys_by_uid(store):
    ident = up.Identity(uid="u1", provider="google.com")
    doc = up.apply_patch(store, ident, {"preferences": {"vibe": "tactical", "push": 80}})

    assert store.get("u1")["created_at"] == NOW
    assert doc["identity"] == {"uid": "u1", "provider": "google.com"}

    # A second PATCH updates the same document in place.
    doc = up.apply_patch(store, ident, {"preferences": {"push": 40}})
    assert doc["preferences"] == {"vibe": "tactical", "push": 40}


def test_patch_deletes_leaves_and_merges_nested_maps(store):
    ident = up.Identity(uid="u1")
    up.apply_patch(store, ident, {"preferences": {"a": 1, "b": 2}, "referral": {"code": "X"}})
    doc = up.apply_patch(store, ident, {"preferences": {"b": None, "c": 3}, "referral": {"code": None}})
    assert doc["preferences"] == {"a": 1, "c": 3}
    assert "code" not in doc["referral"]
    assert doc["updated_at"] == NOW


def test_referral_code_is_write_once(store):
    ident = up.Identity(uid="u1")
    up.apply_patch(store, ident, {"referral": {"code": "FRIEND-42"}})

    # A later push carrying another code leaves the recorded one alone; the rest still lands.
    doc = up.apply_patch(store, ident, {"referral": {"code": "SOMEONE-ELSE"}, "preferences": {"vibe": "friendly"}})
    assert doc["referral"] == {"code": "FRIEND-42", "entered_at": NOW}
    assert doc["preferences"] == {"vibe": "friendly"}

    # Clearing it still works, and the next code is then the first one again.
    up.apply_patch(store, ident, {"referral": {"code": None}})
    doc = up.apply_patch(store, ident, {"referral": {"code": "LATER-7"}})
    assert doc["referral"]["code"] == "LATER-7"


def test_jsonable_formats_timestamps():
    assert jsonable({"t": NOW, "n": [1, {"u": NOW}]}) == {"t": "2026-09-17T12:00:00Z", "n": [1, {"u": "2026-09-17T12:00:00Z"}]}


# ── HTTP ──────────────────────────────────────────────────────────────────────


def test_http_patch_and_get_round_trip(store):
    auth = AuthInfo(uid="u1", provider=None)
    status, body = _call("PATCH", {"preferences": {"vibe": "quiet_closer"}}, auth=auth)
    assert status == 200
    assert body["preferences"] == {"vibe": "quiet_closer"}
    assert body["created_at"] == "2026-09-17T12:00:00Z"

    status, body = _call("GET", auth=auth)
    assert status == 200 and body["preferences"]["vibe"] == "quiet_closer"


def test_http_requires_a_token(store):
    """No Authorization header → 401, whatever the body says. There is no signed-out path."""
    status, body = _call("PATCH", {"preferences": {"vibe": "quiet_closer"}})
    assert status == 401 and body["error"]["status"] == "UNAUTHENTICATED"
    assert _call("GET")[0] == 401
    assert store.get("u1") is None


def test_http_errors(store):
    auth = AuthInfo(uid="u1", provider=None)
    assert _call("GET", auth=auth)[0] == 404
    assert _call("POST", {"preferences": {"vibe": "tactical"}}, auth=auth)[0] == 405
    assert _call("PATCH", {"preferences": {"push": "high"}}, auth=auth)[0] == 400


def test_http_signed_in_patch_uses_uid(store):
    status, body = _call("PATCH", {"app": {"platform": "ios"}},
                         auth=AuthInfo(uid="u9", provider="apple.com"))
    assert status == 200
    assert body["identity"]["uid"] == "u9" and body["identity"]["provider"] == "apple.com"
    assert body["app"]["platform"] == "ios"
    assert store.get("u9") is not None


def test_http_invalid_token_is_rejected(store):
    assert _call("PATCH", {"app": {"platform": "ios"}}, invalid_token=True)[0] == 401
