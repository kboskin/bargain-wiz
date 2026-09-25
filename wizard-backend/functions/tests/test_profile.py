"""Tests for the profile endpoint and the Firestore merge rules behind it."""

import asyncio
from datetime import UTC, datetime

import pytest

import main
from core.auth.firebase import AuthInfo
from core.errors import BadRequest
from core.firestore import FieldOp
from core.observability import StructuredLogger
from core.utils import JsonValue, Validation
from features.profile.domain.patches import ProfilePatchBody
from features.profile.domain.service import ProfileService
from support import FixedClock, InMemoryProfileStore, StaticAuthenticator, call, install

NOW = datetime(2026, 9, 17, 12, 0, tzinfo=UTC)
U1 = AuthInfo(uid="u1")
DELETE, SERVER_TIME = FieldOp.DELETE, FieldOp.SERVER_TIME


def _patch(service: ProfileService, auth: AuthInfo, body: dict) -> dict:
    return asyncio.run(service.patch(auth, body))


def build_patch(body: dict, auth: AuthInfo) -> dict:
    """What the service merges for [body]: validated (a 400 when it does not fit), then built."""
    return Validation.parse(ProfilePatchBody, body).to_patch(auth)


@pytest.fixture
def store() -> InMemoryProfileStore:
    return InMemoryProfileStore(FixedClock(NOW))


@pytest.fixture
def service(store) -> ProfileService:
    return ProfileService(store, StructuredLogger.named("profile"))


def _call(monkeypatch, store, method, body=None, auth: AuthInfo | None = None, invalid_token=False):
    headers = {"Authorization": "Bearer fake"} if (auth or invalid_token) else {}
    install(
        monkeypatch,
        profile_store=store,
        authenticator=StaticAuthenticator(auth, invalid_token=invalid_token),
    )
    status, response, _ = call(main.profile, method, "/profile", body, headers=headers)
    return status, response


# ── validation ────────────────────────────────────────────────────────────────


def test_build_patch_validates_and_normalises_known_sections():
    patch = build_patch(
        {
            "preferences": {
                "vibe": " Tactical ",
                "push": 140,
                "deal_size": 550,
                "marketplace": None,
                "hurdles": ["Starting", "", 3, "fair_price"],
                "experience_level": "pro",
                "gone": None,
            },
            "onboarding_status": {"completed": True},
            "referral": {"code": " FRIEND-42 "},
            "app": {"platform": "android", "flavor": "dev"},  # flavor: no longer stored
            "unknown_section": {"x": 1},
        },
        U1,
    )
    # Fields this backend reads are coerced; a question it has never heard of rides along as
    # sent, which is what lets a screen be added in Remote Config without a deploy.
    assert patch["preferences"] == {
        "vibe": "tactical",
        "push": 100,
        "deal_size": 550.0,
        "marketplace": DELETE,
        "hurdles": ["starting", "fair_price"],
        "experience_level": "pro",
        "gone": DELETE,
    }
    assert patch["onboarding_status"] == {"completed_at": SERVER_TIME}
    assert patch["referral"] == {"code": "FRIEND-42", "entered_at": SERVER_TIME}
    assert patch["app"] == {"platform": "android"}
    assert patch["identity"] == {"uid": "u1"}
    assert (
        "unknown_section" not in patch
        and patch["schema_version"] == ProfilePatchBody.SCHEMA_VERSION
    )
    assert ProfilePatchBody.unknown_sections({"app": {}, "unknown_section": {}}) == [
        "unknown_section"
    ]


def test_build_patch_keeps_the_fcm_token_whole():
    token = "d" * 40 + ":APA91b" + "x" * 200  # longer than any other `app` field may be
    assert build_patch({"app": {"fcm_token": f" {token} "}}, U1)["app"] == {"fcm_token": token}
    with pytest.raises(BadRequest):
        build_patch({"app": {"fcm_token": 42}}, U1)


def test_build_patch_stores_the_launch_time_as_a_timestamp():
    patch = build_patch({"app": {"last_opened_at": "2026-09-17T12:00:00.000Z"}}, U1)
    assert patch["app"] == {
        "last_opened_at": NOW
    }  # a datetime, which Firestore stores as a timestamp
    with pytest.raises(BadRequest):
        build_patch({"app": {"last_opened_at": "yesterday"}}, U1)


def test_build_patch_rejects_wrong_types():
    with pytest.raises(BadRequest):
        build_patch({"preferences": {"push": "high"}}, U1)
    with pytest.raises(BadRequest):
        build_patch({"referral": "code"}, U1)


# ── merge flows ───────────────────────────────────────────────────────────────


def test_patch_keys_by_uid(service, store):
    auth = AuthInfo(uid="u1", provider="google.com")
    doc = _patch(service, auth, {"preferences": {"vibe": "tactical", "push": 80}})

    assert store.doc("u1")["created_at"] == NOW
    assert doc["identity"] == {"uid": "u1", "provider": "google.com"}

    # A second PATCH updates the same document in place.
    doc = _patch(service, auth, {"preferences": {"push": 40}})
    assert doc["preferences"] == {"vibe": "tactical", "push": 40}


def test_patch_deletes_leaves_and_merges_nested_maps(service):
    _patch(service, U1, {"preferences": {"a": 1, "b": 2}, "referral": {"code": "X"}})
    doc = _patch(service, U1, {"preferences": {"b": None, "c": 3}, "referral": {"code": None}})
    assert doc["preferences"] == {"a": 1, "c": 3}
    assert "code" not in doc["referral"]
    assert doc["updated_at"] == NOW


def test_referral_code_is_write_once(service):
    _patch(service, U1, {"referral": {"code": "FRIEND-42"}})

    # A later push carrying another code leaves the recorded one alone; the rest still lands.
    doc = _patch(
        service, U1, {"referral": {"code": "SOMEONE-ELSE"}, "preferences": {"vibe": "friendly"}}
    )
    assert doc["referral"] == {"code": "FRIEND-42", "entered_at": NOW}
    assert doc["preferences"] == {"vibe": "friendly"}

    # Clearing it still works, and the next code is then the first one again.
    _patch(service, U1, {"referral": {"code": None}})
    doc = _patch(service, U1, {"referral": {"code": "LATER-7"}})
    assert doc["referral"]["code"] == "LATER-7"


def test_json_values_format_timestamps():
    assert JsonValue.of({"t": NOW, "n": [1, {"u": NOW}]}) == {
        "t": "2026-09-17T12:00:00Z",
        "n": [1, {"u": "2026-09-17T12:00:00Z"}],
    }


# ── HTTP ──────────────────────────────────────────────────────────────────────


def test_http_patch_and_get_round_trip(monkeypatch, store):
    status, body = _call(
        monkeypatch, store, "PATCH", {"preferences": {"vibe": "quiet_closer"}}, auth=U1
    )
    assert status == 200
    assert body["preferences"] == {"vibe": "quiet_closer"}
    assert body["created_at"] == "2026-09-17T12:00:00Z"

    status, body = _call(monkeypatch, store, "GET", auth=U1)
    assert status == 200 and body["preferences"]["vibe"] == "quiet_closer"


def test_http_requires_a_token(monkeypatch, store):
    """No Authorization header → 401, whatever the body says. There is no signed-out path."""
    status, body = _call(monkeypatch, store, "PATCH", {"preferences": {"vibe": "quiet_closer"}})
    assert status == 401 and body["error"]["status"] == "UNAUTHENTICATED"
    assert _call(monkeypatch, store, "GET")[0] == 401
    assert store.doc("u1") is None


def test_http_errors(monkeypatch, store):
    assert _call(monkeypatch, store, "GET", auth=U1)[0] == 404
    assert (
        _call(monkeypatch, store, "POST", {"preferences": {"vibe": "tactical"}}, auth=U1)[0] == 405
    )
    assert _call(monkeypatch, store, "PATCH", {"preferences": {"push": "high"}}, auth=U1)[0] == 400


def test_http_signed_in_patch_uses_uid(monkeypatch, store):
    status, body = _call(
        monkeypatch,
        store,
        "PATCH",
        {"app": {"platform": "ios"}},
        auth=AuthInfo(uid="u9", provider="apple.com"),
    )
    assert status == 200
    assert body["identity"] == {"uid": "u9", "provider": "apple.com"}
    assert body["app"]["platform"] == "ios"
    assert store.doc("u9") is not None


def test_http_invalid_token_is_rejected(monkeypatch, store):
    assert (
        _call(monkeypatch, store, "PATCH", {"app": {"platform": "ios"}}, invalid_token=True)[0]
        == 401
    )
