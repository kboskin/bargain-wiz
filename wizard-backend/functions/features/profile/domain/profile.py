"""User profile documents in Firestore: schema, validation and merge rules.

One document per person at `users/{uid}`, the same document that parents that person's
`conversations` and `limits` subcollections (see conversation_store.py) — everything about a
user lives under one path. `doc_id` is always the Firebase Auth uid: every install signs in
anonymously before it can reach this endpoint (CONVERSATIONS.md §2), so there is no
signed-out document to key by and no second identifier to reconcile. The client sends no
identity of its own — the ID token is the identity.

Sections (all optional in a PATCH; nested maps merge, `null` deletes a leaf):

    preferences   every answer the funnel collects, under the remote-config
                  `answer_key_name` that is also the field name. The ones this backend reads
                  (vibe, push, marketplace, deals_per_month, deal_size, hurdles, locale) are
                  typed and coerced; any other question the funnel adds rides along as a
                  JSON leaf, so a new screen needs no change here. There is no second copy
                  of the answers: `preferences` is the record.
    onboarding_status
                  `completed_at`, stamped by the server the first time a client reports the
                  funnel finished. Experiment assignment is Firebase A/B Testing's job
                  (Analytics user properties), not stored here.
    referral      code entered during onboarding, write-once ([WRITE_ONCE])
    app           last seen platform / version / flavor / locale
    identity      server-managed: uid, provider

Pure Python; `ProfileStore` abstracts Firestore so the logic is unit-testable.
"""
import logging
from typing import Any, Protocol

from pydantic import BaseModel, ConfigDict, field_validator, model_validator

from core.errors import BadRequest, NotFound, Unauthorized
from core.firestore import DELETE, SERVER_TIME
from core.validation import clip_text, validate_model

logger = logging.getLogger("profile")

SCHEMA_VERSION = 2



SECTIONS = ("preferences", "onboarding_status", "referral", "app")

# `(section, field)` pairs a client fills once and may never re-set. A referral code credits
# whoever brought this person in: re-entering it would re-attribute an install that is already
# credited, so a later PATCH carrying one is dropped. The Profile screen hides the field
# (`ProfileFields.lockedKeys`), this is what makes it true for an older or tampered client.
# An explicit null still deletes — forgetting a code has to stay possible.
WRITE_ONCE = (("referral", "code"),)


# Update markers (DELETE / SERVER_TIME) live in markers.py and are re-exported here.


class ArrayUnion(BaseModel):
    """Firestore array-union marker; `ArrayUnion([value])` reads naturally in patches."""

    model_config = ConfigDict(frozen=True)

    values: list

    def __init__(self, values: list | None = None, /, **data):
        super().__init__(values=list(values) if values is not None else data.get("values", []))


class Identity(BaseModel):
    """Who the request is for: a Firebase uid and/or the install's UUID."""

    model_config = ConfigDict(frozen=True)

    uid: str | None = None
    provider: str | None = None

    @property
    def doc_id(self) -> str:
        if self.uid:
            return self.uid
        raise Unauthorized("Sign in required (send a Firebase ID token)")


# ── validation ─────────────────────────────────────────────────────────────────


def _leaf(value: object, name: str, depth: int = 0) -> Any:
    """A JSON leaf we are willing to store: str, number, bool, None(→DELETE), list of leaves,
    or a map of leaves (one level). Size is not bounded here: Firestore's 1 MiB document
    limit is what stops a runaway payload."""
    if value is None:
        return DELETE
    if isinstance(value, bool | int | float):
        return value
    if isinstance(value, str):
        return value.strip()
    if isinstance(value, list):
        return [_leaf(v, name, depth + 1) for v in value if v is not None]
    if isinstance(value, dict) and depth == 0:
        return {str(k): _leaf(v, f"{name}.{k}", depth + 1) for k, v in value.items() if v is not None}
    raise ValueError(f"{name} has an unsupported value")


class _Section(BaseModel):
    """A PATCH section: only fields the client sent are written; an explicit null deletes."""

    model_config = ConfigDict(extra="ignore")

    def to_patch(self) -> dict:
        patch: dict[str, Any] = {}
        for name in self.model_fields_set:
            value = getattr(self, name)
            patch[name] = DELETE if value is None else value
        return patch


class PreferencesPatch(_Section):
    """Every answer the funnel collected. The fields below are the ones the AI functions
    read, so they are typed and coerced; anything else the screens collect is kept as sent
    (`extra="allow"`), which is what lets a question added in Remote Config be recorded
    without a deploy. An explicit null still deletes the answer."""

    model_config = ConfigDict(extra="allow")

    vibe: str | None = None
    push: int | None = None
    marketplace: str | None = None
    deals_per_month: str | None = None
    deal_size: float | None = None
    locale: str | None = None
    hurdles: list[str] | None = None

    @model_validator(mode="before")
    @classmethod
    def _clean_undeclared_answers(cls, data: object) -> object:
        """Answers this backend does not model are stored as JSON leaves. Validated here
        rather than in `to_patch` so an unstorable value is a 400, not a 500."""
        if not isinstance(data, dict):
            return data
        declared = set(cls.model_fields)
        return {
            key: value if key in declared else _leaf(value, f"preferences.{key}")
            for key, value in data.items()
        }

    @field_validator("vibe", "marketplace", "deals_per_month", "locale", mode="before")
    @classmethod
    def _lower_text(cls, value: object) -> str | None:
        text = clip_text(value, 40, ellipsis=False)
        return text.lower() if text else None

    @field_validator("push", mode="before")
    @classmethod
    def _push(cls, value: object) -> int | None:
        if value is None:
            return None
        if isinstance(value, bool) or not isinstance(value, int | float):
            raise ValueError("must be a number")
        return int(min(100, max(0, value)))

    @field_validator("deal_size", mode="before")
    @classmethod
    def _deal_size(cls, value: object) -> float | None:
        if value is None:
            return None
        if isinstance(value, bool) or not isinstance(value, int | float):
            raise ValueError("must be a number")
        return float(value)

    @field_validator("hurdles", mode="before")
    @classmethod
    def _hurdles(cls, value: object) -> list[str] | None:
        if value is None:
            return None
        if not isinstance(value, list):
            raise ValueError("must be a list of ids")
        hurdles = [str(v).strip().lower() for v in value if isinstance(v, str) and v.strip()]
        return hurdles or None


class OnboardingStatusPatch(_Section):
    """Whether the funnel is finished. The client reports the fact; the server stamps the
    time, so a wrong device clock cannot date it. Only the first `true` matters — a later
    one restamps, which is harmless, and `null` clears it."""

    completed: bool | None = None

    def to_patch(self) -> dict:
        if "completed" not in self.model_fields_set:
            return {}
        return {"completed_at": SERVER_TIME if self.completed else DELETE}


class ReferralPatch(_Section):
    code: str | None = None

    @field_validator("code", mode="before")
    @classmethod
    def _code(cls, value: object) -> str | None:
        return clip_text(value, 40, ellipsis=False)

    def to_patch(self) -> dict:
        if "code" not in self.model_fields_set:
            return {}
        if self.code is None:
            return {"code": DELETE}
        return {"code": self.code, "entered_at": SERVER_TIME}


class AppPatch(_Section):
    platform: str | None = None
    version: str | None = None
    flavor: str | None = None
    locale: str | None = None

    @field_validator("platform", "version", "flavor", "locale", mode="before")
    @classmethod
    def _text(cls, value: object) -> str | None:
        return clip_text(value, 64, ellipsis=False)


class ProfilePatchBody(BaseModel):
    """Body of `PATCH /profile`; unknown top-level sections are ignored (the funnel changes
    faster than the client)."""

    model_config = ConfigDict(extra="ignore")

    preferences: PreferencesPatch | None = None
    onboarding_status: OnboardingStatusPatch | None = None
    referral: ReferralPatch | None = None
    app: AppPatch | None = None

def build_patch(body: dict, identity: Identity) -> dict:
    """Validated Firestore merge payload for one PATCH body."""
    model = validate_model(ProfilePatchBody, body, BadRequest)
    for key in set(body) - set(ProfilePatchBody.model_fields):
        logger.info("ignoring unknown profile section %r", key)
    patch: dict[str, Any] = {"schema_version": SCHEMA_VERSION, "updated_at": SERVER_TIME}
    for name in SECTIONS:
        section = getattr(model, name)
        if section is None:
            continue
        data = section.to_patch()
        if data:
            patch[name] = data
    identity_patch: dict[str, Any] = {}
    if identity.uid:
        identity_patch["uid"] = identity.uid
    if identity.provider:
        identity_patch["provider"] = identity.provider
    if identity_patch:
        patch["identity"] = identity_patch
    return patch


# ── merging ────────────────────────────────────────────────────────────────────

class ProfileStore(Protocol):
    def get(self, doc_id: str) -> dict | None: ...
    def merge(self, doc_id: str, patch: dict) -> None: ...


def drop_write_once(patch: dict, current: dict | None) -> dict:
    """Strips the [WRITE_ONCE] fields `current` already records, so the first value given
    stands. The section goes with the field: what is left of it (`entered_at`) is the stamp
    the server wrote for that first value."""
    for section, field in WRITE_ONCE:
        incoming = patch.get(section)
        if not isinstance(incoming, dict) or incoming.get(field, DELETE) is DELETE:
            continue  # nothing set, or an explicit delete
        stored = (current or {}).get(section)
        if isinstance(stored, dict) and stored.get(field):
            logger.info("ignoring %s.%s: already set", section, field)
            patch.pop(section)
    return patch


def apply_patch(store: ProfileStore, identity: Identity, body: dict) -> dict:
    """PATCH semantics: merge the validated body into `users/{uid}`, creating it on the first
    call. Returns the resulting document."""
    doc_id = identity.doc_id
    current = store.get(doc_id)
    patch = drop_write_once(build_patch(body, identity), current)
    if current is None:
        patch["created_at"] = SERVER_TIME
    store.merge(doc_id, patch)
    return store.get(doc_id) or {}


def read_profile(store: ProfileStore, identity: Identity) -> dict:
    doc = store.get(identity.doc_id)
    if doc is None:
        raise NotFound("No profile yet")
    return doc

