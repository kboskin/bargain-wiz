"""User profile documents in Firestore: schema, validation and merge rules.

One document per person at `users/{doc_id}`, the same document that parents that person's
`conversations` and `limits` subcollections (see conversation_store.py) — everything about a
user lives under one path. `doc_id` is the Firebase Auth uid, or `inst_<installation_id>`
while the user is signed out. When a signed-out installation later signs in, its anonymous
document is folded into the uid document (existing uid values win) and marked
`identity.merged_into`.

Sections (all optional in a PATCH; nested maps merge, `null` deletes a leaf):

    preferences   stable, typed fields the app logic depends on (vibe, push, marketplace,
                  deals_per_month, deal_size, locale) — the client derives them from answers
    onboarding    raw funnel answers keyed by the remote-config `answer_key_name`, plus
                  `flow`: the ordered trace of screens shown (key, type, title, options
                  offered) — enough to interpret every answer without the config that
                  produced it. Experiment assignment itself is Firebase A/B Testing's job
                  (Analytics user properties), not stored here.
    referral      code entered during onboarding
    app           last seen platform / version / flavor / locale
    identity      server-managed: uid, provider, installation_ids, merged_from/merged_into

Pure Python; `ProfileStore` abstracts Firestore so the logic is unit-testable.
"""
import logging
import re
from datetime import UTC, datetime
from typing import Any, Protocol

from pydantic import BaseModel, ConfigDict, field_validator

import config
from errors import BadRequest, NotFound
from markers import DELETE, SERVER_TIME, to_firestore
from validation import clip_text, validate_model

logger = logging.getLogger("profile")

SCHEMA_VERSION = 1


_INSTALLATION_ID = re.compile(r"^[0-9a-f]{8}-?[0-9a-f]{4}-?[0-9a-f]{4}-?[0-9a-f]{4}-?[0-9a-f]{12}$")

SECTIONS = ("preferences", "onboarding", "referral", "app")


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
    installation_id: str | None = None

    @property
    def doc_id(self) -> str:
        if self.uid:
            return self.uid
        if self.installation_id:
            return anonymous_doc_id(self.installation_id)
        raise BadRequest("Sign in or send an installation_id")


def anonymous_doc_id(installation_id: str) -> str:
    return f"inst_{installation_id}"


def validate_installation_id(raw: object) -> str | None:
    if raw is None:
        return None
    if not isinstance(raw, str) or not _INSTALLATION_ID.match(raw.strip().lower()):
        raise BadRequest("installation_id must be a UUID")
    return raw.strip().lower()


# ── validation ─────────────────────────────────────────────────────────────────


def _leaf(value: object, name: str, depth: int = 0) -> Any:
    """A JSON leaf we are willing to store: str, number, bool, None(→DELETE), list of leaves,
    or a small map of leaves (one level)."""
    if value is None:
        return DELETE
    if isinstance(value, bool | int | float):
        return value
    if isinstance(value, str):
        return value.strip()[:config.PROFILE_MAX_STR.value]
    if isinstance(value, list):
        if len(value) > config.PROFILE_MAX_LIST.value:
            raise ValueError(f"{name} has more than {config.PROFILE_MAX_LIST.value} items")
        return [_leaf(v, name, depth + 1) for v in value if v is not None]
    if isinstance(value, dict) and depth == 0:
        return {str(k)[:config.PROFILE_MAX_KEY.value]: _leaf(v, f"{name}.{k}", depth + 1) for k, v in value.items() if v is not None}
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
    vibe: str | None = None
    push: int | None = None
    marketplace: str | None = None
    deals_per_month: str | None = None
    deal_size: float | None = None
    locale: str | None = None
    hurdles: list[str] | None = None

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
        hurdles = [str(v).strip().lower()[:config.PROFILE_MAX_KEY.value] for v in value if isinstance(v, str) and v.strip()]
        return hurdles[:config.PROFILE_MAX_HURDLES.value] or None


class FlowStep(_Section):
    """One screen of the onboarding trace: what was asked and which options were offered."""

    index: int | None = None
    key: str | None = None
    type: str | None = None
    title: str | None = None
    options: list[str] | None = None

    @field_validator("index", mode="before")
    @classmethod
    def _index(cls, value: object) -> int | None:
        return value if isinstance(value, int) and not isinstance(value, bool) else None

    @field_validator("key", "type", mode="before")
    @classmethod
    def _key(cls, value: object) -> str | None:
        return clip_text(value, config.PROFILE_MAX_KEY.value, ellipsis=False) if isinstance(value, str) else None

    @field_validator("title", mode="before")
    @classmethod
    def _title(cls, value: object) -> str | None:
        return clip_text(value, 200, ellipsis=False) if isinstance(value, str) else None

    @field_validator("options", mode="before")
    @classmethod
    def _options(cls, value: object) -> list[str] | None:
        if not isinstance(value, list):
            return None
        return [str(o)[:config.PROFILE_MAX_KEY.value] for o in value[:config.PROFILE_MAX_LIST.value] if o is not None]

    def to_dict(self) -> dict:
        return {k: v for k, v in self.model_dump().items() if v is not None}


class OnboardingPatch(_Section):
    answers: dict[str, Any] | None = None
    completed: bool | None = None
    flow: list[FlowStep] | None = None

    @field_validator("answers", mode="before")
    @classmethod
    def _answers(cls, value: object) -> dict | None:
        if value is None:
            return None
        if not isinstance(value, dict):
            raise ValueError("must be an object")
        if len(value) > config.PROFILE_MAX_ANSWERS.value:
            raise ValueError(f"at most {config.PROFILE_MAX_ANSWERS.value} answers")
        return {str(k)[:config.PROFILE_MAX_KEY.value]: _leaf(v, f"answers.{k}") for k, v in value.items()}

    @field_validator("flow", mode="before")
    @classmethod
    def _flow(cls, value: object) -> list | None:
        if value is None:
            return None
        if not isinstance(value, list):
            raise ValueError("must be a list")
        return [step for step in value if isinstance(step, dict)][:config.PROFILE_MAX_FLOW_STEPS.value]

    def to_patch(self) -> dict:
        patch: dict[str, Any] = {}
        if self.answers is not None:
            patch["answers"] = self.answers
        if self.completed is True:
            patch["completed_at"] = SERVER_TIME
        if self.flow is not None:
            patch["flow"] = [step.to_dict() for step in self.flow if step.to_dict()]
        return patch


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

    installation_id: str | None = None
    preferences: PreferencesPatch | None = None
    onboarding: OnboardingPatch | None = None
    referral: ReferralPatch | None = None
    app: AppPatch | None = None

    @field_validator("installation_id", mode="before")
    @classmethod
    def _installation(cls, value: object) -> str | None:
        if value is None:
            return None
        if not isinstance(value, str) or not _INSTALLATION_ID.match(value.strip().lower()):
            raise ValueError("must be a UUID")
        return value.strip().lower()


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
    if identity.installation_id:
        identity_patch["installation_ids"] = ArrayUnion([identity.installation_id])
    if identity_patch:
        patch["identity"] = identity_patch
    return patch


# ── merging ────────────────────────────────────────────────────────────────────

_META_KEYS = ("identity", "schema_version", "created_at", "updated_at")


def fill_missing(target: dict, source: dict) -> dict:
    """Fields present in [source] but absent from [target], nested. Used when folding an
    anonymous profile into a signed-in one: the signed-in values win."""
    out: dict[str, Any] = {}
    for key, value in source.items():
        if key not in target:
            out[key] = value
        elif isinstance(value, dict) and isinstance(target[key], dict):
            nested = fill_missing(target[key], value)
            if nested:
                out[key] = nested
    return out


class ProfileStore(Protocol):
    def get(self, doc_id: str) -> dict | None: ...
    def merge(self, doc_id: str, patch: dict) -> None: ...


def apply_patch(store: ProfileStore, identity: Identity, body: dict) -> dict:
    """PATCH semantics: fold a pending anonymous profile into the uid profile, then merge
    the validated body. Returns the resulting document."""
    doc_id = identity.doc_id
    merged_from: list[str] = []
    if identity.uid and identity.installation_id:
        anon_id = anonymous_doc_id(identity.installation_id)
        anon = store.get(anon_id)
        if anon and not anon.get("identity", {}).get("merged_into"):
            current = store.get(doc_id) or {}
            missing = fill_missing(current, {k: v for k, v in anon.items() if k not in _META_KEYS})
            if missing:
                store.merge(doc_id, missing)
            store.merge(anon_id, {"identity": {"merged_into": identity.uid, "merged_at": SERVER_TIME}})
            merged_from.append(anon_id)
            logger.info("merged %s into %s", anon_id, doc_id)

    current = store.get(doc_id)
    patch = build_patch(body, identity)
    if current is None:
        patch["created_at"] = SERVER_TIME
    if merged_from:
        patch.setdefault("identity", {})["merged_from"] = ArrayUnion(merged_from)
    store.merge(doc_id, patch)
    return store.get(doc_id) or {}


def read_profile(store: ProfileStore, identity: Identity) -> dict:
    doc = store.get(identity.doc_id)
    if doc is None:
        raise NotFound("No profile yet")
    return doc


def jsonable(value: Any) -> Any:
    """Firestore returns datetimes; the API speaks ISO-8601."""
    if isinstance(value, dict):
        return {k: jsonable(v) for k, v in value.items()}
    if isinstance(value, list):
        return [jsonable(v) for v in value]
    if isinstance(value, datetime):
        return value.astimezone(UTC).isoformat(timespec="seconds").replace("+00:00", "Z")
    return value


# ── stores ─────────────────────────────────────────────────────────────────────


class InMemoryProfileStore:
    """Test double with Firestore merge semantics for our markers."""

    def __init__(self, clock=lambda: datetime.now(UTC)):
        self.docs: dict[str, dict] = {}
        self._clock = clock

    def get(self, doc_id: str) -> dict | None:
        doc = self.docs.get(doc_id)
        return _deepcopy(doc) if doc is not None else None

    def merge(self, doc_id: str, patch: dict) -> None:
        doc = self.docs.setdefault(doc_id, {})
        self._apply(doc, patch)

    def _apply(self, target: dict, patch: dict) -> None:
        for key, value in patch.items():
            if value is DELETE:
                target.pop(key, None)
            elif value is SERVER_TIME:
                target[key] = self._clock()
            elif isinstance(value, ArrayUnion):
                existing = list(target.get(key) or [])
                target[key] = existing + [v for v in value.values if v not in existing]
            elif isinstance(value, dict):
                child = target.get(key)
                if not isinstance(child, dict):
                    child = target[key] = {}
                self._apply(child, value)
            else:
                target[key] = value


def _deepcopy(value: Any) -> Any:
    if isinstance(value, dict):
        return {k: _deepcopy(v) for k, v in value.items()}
    if isinstance(value, list):
        return [_deepcopy(v) for v in value]
    return value


class FirestoreProfileStore:
    def __init__(self, client=None):
        if client is None:
            from firebase_admin import firestore

            client = firestore.client()
        self._collection = client.collection(config.USERS_COLLECTION.value)

    def get(self, doc_id: str) -> dict | None:
        snapshot = self._collection.document(doc_id).get()
        return snapshot.to_dict() if snapshot.exists else None

    def merge(self, doc_id: str, patch: dict) -> None:
        self._collection.document(doc_id).set(self._translate(patch), merge=True)

    @classmethod
    def _translate(cls, value: Any) -> Any:
        from google.cloud import firestore

        if isinstance(value, ArrayUnion):
            return firestore.ArrayUnion(value.values)
        if isinstance(value, dict):
            return {k: cls._translate(v) for k, v in value.items()}
        if isinstance(value, list):
            return [cls._translate(v) for v in value]
        return to_firestore(value)
