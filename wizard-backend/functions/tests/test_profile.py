"""Tests for the profile endpoint and the Firestore merge rules behind it."""
import json
from datetime import UTC, datetime

import pytest
from flask import Flask, request

import config
import main
import user_profile as up
from auth import AuthInfo, StaticAuthenticator

INSTALL = "3fa85f64-5717-4562-b3fc-2c963f66afa6"
NOW = datetime(2026, 9, 17, 12, 0, tzinfo=UTC)


@pytest.fixture
def store(monkeypatch):
    s = up.InMemoryProfileStore(clock=lambda: NOW)
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
            "installation_id": INSTALL,
            "preferences": {"vibe": " Tactical ", "push": 140, "deal_size": 550, "marketplace": None, "bogus": 1,
                            "hurdles": ["Starting", "", 3, "fair_price"]},
            "onboarding": {"answers": {"main_hurdle": ["starting", "fair_price"], "risk_tolerance": 60, "gone": None},
                           "completed": True,
                           "flow": [{"index": 0, "key": "main_hurdle", "type": "multiSelect", "title": "Where…",
                                     "options": ["starting", "counter_offers", None]}, "junk"]},
            "referral": {"code": " FRIEND-42 "},
            "app": {"platform": "android", "flavor": "dev"},
            "unknown_section": {"x": 1},
        },
        up.Identity(installation_id=INSTALL),
    )
    assert patch["preferences"] == {"vibe": "tactical", "push": 100, "deal_size": 550.0, "marketplace": up.DELETE,
                                    "hurdles": ["starting", "fair_price"]}
    assert patch["onboarding"]["answers"] == {"main_hurdle": ["starting", "fair_price"], "risk_tolerance": 60, "gone": up.DELETE}
    assert patch["onboarding"]["completed_at"] is up.SERVER_TIME
    assert patch["onboarding"]["flow"] == [{"index": 0, "key": "main_hurdle", "type": "multiSelect", "title": "Where…",
                                            "options": ["starting", "counter_offers"]}]
    assert patch["referral"] == {"code": "FRIEND-42", "entered_at": up.SERVER_TIME}
    assert patch["app"] == {"platform": "android", "flavor": "dev"}
    assert patch["identity"] == {"installation_ids": up.ArrayUnion([INSTALL])}
    assert "unknown_section" not in patch and patch["schema_version"] == up.SCHEMA_VERSION


def test_build_patch_rejects_wrong_types_and_limits():
    ident = up.Identity(installation_id=INSTALL)
    with pytest.raises(up.BadRequest):
        up.build_patch({"preferences": {"push": "high"}}, ident)
    with pytest.raises(up.BadRequest):
        up.build_patch({"onboarding": {"answers": {f"k{i}": i for i in range(config.PROFILE_MAX_ANSWERS.value + 1)}}}, ident)
    with pytest.raises(up.BadRequest):
        up.build_patch({"referral": "code"}, ident)
    with pytest.raises(up.BadRequest):
        up.validate_installation_id("not-a-uuid")
    with pytest.raises(up.BadRequest):
        _ = up.Identity().doc_id


def test_fill_missing_keeps_target_values():
    target = {"preferences": {"vibe": "tactical"}, "referral": {"code": "A"}}
    source = {"preferences": {"vibe": "friendly", "push": 60}, "onboarding": {"answers": {"x": 1}}}
    assert up.fill_missing(target, source) == {"preferences": {"push": 60}, "onboarding": {"answers": {"x": 1}}}


# ── merge flows ───────────────────────────────────────────────────────────────


def test_anonymous_then_sign_in_folds_the_anonymous_profile(store):
    anon = up.Identity(installation_id=INSTALL)
    up.apply_patch(store, anon, {"preferences": {"vibe": "tactical", "push": 80}, "onboarding": {"answers": {"main_hurdle": ["starting"]}, "completed": True}})
    assert store.get(f"inst_{INSTALL}")["created_at"] == NOW

    signed = up.Identity(uid="u1", provider="google.com", installation_id=INSTALL)
    # The signed-in profile already has a vibe → it wins; everything else is filled in.
    store.merge("u1", {"preferences": {"vibe": "friendly"}})
    doc = up.apply_patch(store, signed, {"app": {"platform": "ios"}})

    assert doc["preferences"] == {"vibe": "friendly", "push": 80}
    assert doc["onboarding"]["answers"] == {"main_hurdle": ["starting"]}
    assert doc["identity"]["uid"] == "u1" and doc["identity"]["provider"] == "google.com"
    assert doc["identity"]["installation_ids"] == [INSTALL]
    assert doc["identity"]["merged_from"] == [f"inst_{INSTALL}"]
    assert store.get(f"inst_{INSTALL}")["identity"]["merged_into"] == "u1"

    # A second signed-in PATCH does not merge again or duplicate the installation id.
    doc = up.apply_patch(store, signed, {"preferences": {"push": 40}})
    assert doc["preferences"]["push"] == 40
    assert doc["identity"]["installation_ids"] == [INSTALL]
    assert doc["identity"]["merged_from"] == [f"inst_{INSTALL}"]


def test_patch_deletes_leaves_and_merges_nested_maps(store):
    ident = up.Identity(installation_id=INSTALL)
    up.apply_patch(store, ident, {"onboarding": {"answers": {"a": 1, "b": 2}}, "referral": {"code": "X"}})
    doc = up.apply_patch(store, ident, {"onboarding": {"answers": {"b": None, "c": 3}}, "referral": {"code": None}})
    assert doc["onboarding"]["answers"] == {"a": 1, "c": 3}
    assert "code" not in doc["referral"]
    assert doc["updated_at"] == NOW


def test_jsonable_formats_timestamps():
    assert up.jsonable({"t": NOW, "n": [1, {"u": NOW}]}) == {"t": "2026-09-17T12:00:00Z", "n": [1, {"u": "2026-09-17T12:00:00Z"}]}


# ── HTTP ──────────────────────────────────────────────────────────────────────


def test_http_patch_and_get_for_a_signed_out_installation(store):
    status, body = _call("PATCH", {"installation_id": INSTALL, "preferences": {"vibe": "quiet_closer"}})
    assert status == 200
    assert body["preferences"] == {"vibe": "quiet_closer"}
    assert body["created_at"] == "2026-09-17T12:00:00Z"

    status, body = _call("GET", query=f"?installation_id={INSTALL}")
    assert status == 200 and body["preferences"]["vibe"] == "quiet_closer"


def test_http_errors(store):
    assert _call("GET", query="?installation_id=3fa85f64-5717-4562-b3fc-2c963f66afa7")[0] == 404
    status, body = _call("PATCH", {"preferences": {"vibe": "x"}})
    assert status == 400 and "installation_id" in body["error"]["message"]
    assert _call("POST", {"installation_id": INSTALL})[0] == 405
    status, body = _call("PATCH", {"installation_id": "nope"})
    assert status == 400


def test_http_signed_in_patch_uses_uid_and_merges(store):
    store.merge(f"inst_{INSTALL}", {"preferences": {"push": 20}, "identity": {"installation_ids": [INSTALL]}})
    status, body = _call("PATCH", {"installation_id": INSTALL, "app": {"platform": "ios"}},
                         auth=AuthInfo(uid="u9", provider="apple.com"))
    assert status == 200
    assert body["identity"]["uid"] == "u9" and body["identity"]["provider"] == "apple.com"
    assert body["preferences"]["push"] == 20
    assert store.get("u9") is not None


def test_http_invalid_token_is_rejected(store):
    assert _call("PATCH", {"installation_id": INSTALL}, invalid_token=True)[0] == 401
