"""What a `PATCH /profile` may say, and the Firestore merge it becomes.

Sections (all optional; nested maps merge, `null` deletes a leaf):

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
    referral      code entered during onboarding, write-once (see `service.WRITE_ONCE`)
    app           last seen platform / version / locale, and that install's
                  `fcm_token` (the address a push goes to; one per profile, last device wins);
                  `last_opened_at`, sent by the app on each launch
    identity      server-managed: uid, provider
"""

from datetime import datetime
from typing import Any, ClassVar

from pydantic import BaseModel, ConfigDict, field_validator, model_validator

from core.auth.firebase import AuthInfo
from core.firestore import FieldOp
from core.utils import Text

# ── validation ─────────────────────────────────────────────────────────────────


class _Section(BaseModel):
    """A PATCH section: only fields the client sent are written; an explicit null deletes."""

    model_config = ConfigDict(extra="ignore")

    def to_patch(self) -> dict:
        patch: dict[str, Any] = {}
        for name in self.model_fields_set:
            value = getattr(self, name)
            patch[name] = FieldOp.DELETE if value is None else value
        return patch


class PreferencesPatch(_Section):
    """Every answer the funnel collected. The fields below are the ones the AI functions
    read, so they are typed and coerced; anything else the screens collect is kept as sent
    (`extra="allow"`), which is what lets a question added in Remote Config be recorded
    without a deploy. An explicit null still deletes the answer."""

    model_config = ConfigDict(extra="allow")

    MAX_TEXT_CHARS: ClassVar[int] = 40
    PUSH_RANGE: ClassVar[tuple[int, int]] = (0, 100)

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
            key: value if key in declared else cls.leaf(value, f"preferences.{key}")
            for key, value in data.items()
        }

    @classmethod
    def leaf(cls, value: object, name: str, depth: int = 0) -> Any:
        """A JSON leaf we are willing to store: str, number, bool, None(→FieldOp.DELETE), list of
        leaves, or a map of leaves (one level). Size is not bounded here: Firestore's 1 MiB
        document limit is what stops a runaway payload."""
        if value is None:
            return FieldOp.DELETE
        if isinstance(value, bool | int | float):
            return value
        if isinstance(value, str):
            return value.strip()
        if isinstance(value, list):
            return [cls.leaf(v, name, depth + 1) for v in value if v is not None]
        if isinstance(value, dict) and depth == 0:
            return {
                str(k): cls.leaf(v, f"{name}.{k}", depth + 1)
                for k, v in value.items()
                if v is not None
            }
        raise ValueError(f"{name} has an unsupported value")

    @field_validator("vibe", "marketplace", "deals_per_month", "locale", mode="before")
    @classmethod
    def _lower_text(cls, value: object) -> str | None:
        text = Text.clip(value, cls.MAX_TEXT_CHARS, ellipsis=False)
        return text.lower() if text else None

    @field_validator("push", mode="before")
    @classmethod
    def _push(cls, value: object) -> int | None:
        if value is None:
            return None
        if isinstance(value, bool) or not isinstance(value, int | float):
            raise ValueError("must be a number")
        low, high = cls.PUSH_RANGE
        return int(min(high, max(low, value)))

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
        return {"completed_at": FieldOp.SERVER_TIME if self.completed else FieldOp.DELETE}


class ReferralPatch(_Section):
    MAX_CODE_CHARS: ClassVar[int] = 40

    code: str | None = None

    @field_validator("code", mode="before")
    @classmethod
    def _code(cls, value: object) -> str | None:
        return Text.clip(value, cls.MAX_CODE_CHARS, ellipsis=False)

    def to_patch(self) -> dict:
        if "code" not in self.model_fields_set:
            return {}
        if self.code is None:
            return {"code": FieldOp.DELETE}
        return {"code": self.code, "entered_at": FieldOp.SERVER_TIME}


class AppPatch(_Section):
    MAX_TEXT_CHARS: ClassVar[int] = 64

    platform: str | None = None
    version: str | None = None
    locale: str | None = None
    fcm_token: str | None = None
    last_opened_at: datetime | None = None  # sent by the app on every launch, device clock

    @field_validator("platform", "version", "locale", mode="before")
    @classmethod
    def _text(cls, value: object) -> str | None:
        return Text.clip(value, cls.MAX_TEXT_CHARS, ellipsis=False)

    @field_validator("fcm_token", mode="before")
    @classmethod
    def _token(cls, value: object) -> str | None:
        return Text.trim(value)  # never clipped: a truncated token addresses nothing


class ProfilePatchBody(BaseModel):
    """Body of `PATCH /profile`; unknown top-level sections are ignored (the funnel changes
    faster than the client)."""

    model_config = ConfigDict(extra="ignore")

    SCHEMA_VERSION: ClassVar[int] = 2
    SECTIONS: ClassVar[tuple[str, ...]] = ("preferences", "onboarding_status", "referral", "app")

    preferences: PreferencesPatch | None = None
    onboarding_status: OnboardingStatusPatch | None = None
    referral: ReferralPatch | None = None
    app: AppPatch | None = None

    @classmethod
    def unknown_sections(cls, body: dict) -> list[str]:
        """Top-level keys a body sent that are not sections (ignored, and worth logging)."""
        return sorted(set(body) - set(cls.model_fields))

    def to_patch(self, auth: AuthInfo) -> dict:
        """The Firestore merge payload: the sections sent, the schema version, the timestamp,
        and the identity the ID token proved."""
        patch: dict[str, Any] = {
            "schema_version": self.SCHEMA_VERSION,
            "updated_at": FieldOp.SERVER_TIME,
        }
        for name in self.SECTIONS:
            section = getattr(self, name)
            if section is not None and (data := section.to_patch()):
                patch[name] = data
        identity: dict[str, Any] = {"uid": auth.uid}
        if auth.provider:
            identity["provider"] = auth.provider
        patch["identity"] = identity
        return patch
