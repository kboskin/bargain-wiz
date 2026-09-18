"""Firebase Auth and App Check verification behind a small interface, so endpoints do not
touch `firebase_admin` directly and tests inject identities instead of monkeypatching."""
import logging
from typing import Protocol

from pydantic import BaseModel, ConfigDict

import config
from errors import Unauthorized

logger = logging.getLogger("auth")


class AuthInfo(BaseModel):
    model_config = ConfigDict(frozen=True)

    uid: str
    provider: str | None = None


class Authenticator(Protocol):
    def optional(self, req) -> AuthInfo | None:
        """Identity from the Authorization header, or None when absent."""

    def require(self, req) -> AuthInfo:
        """Identity from the Authorization header; Unauthorized when absent."""

    def verify_app_check(self, req) -> None:
        """Unauthorized when App Check is enforced and the token is missing or invalid."""


def bearer_token(req) -> str | None:
    header = req.headers.get("Authorization", "")
    if not header.lower().startswith("bearer "):
        return None
    return header[7:].strip() or None


class FirebaseAuthenticator:
    """Verifies Firebase ID tokens; anonymous users are first-class (every install has one).
    A token that is present but invalid is always rejected."""

    def optional(self, req) -> AuthInfo | None:
        token = bearer_token(req)
        if token is None:
            return None
        from firebase_admin import auth as firebase_auth

        try:
            claims = firebase_auth.verify_id_token(token)
        except Exception as exc:
            raise Unauthorized("Invalid Firebase ID token") from exc
        provider = (claims.get("firebase") or {}).get("sign_in_provider")
        return AuthInfo(uid=claims["uid"], provider=provider)

    def require(self, req) -> AuthInfo:
        info = self.optional(req)
        if info is None:
            raise Unauthorized("Sign in required (send a Firebase ID token)")
        return info

    def verify_app_check(self, req) -> None:
        # `https_fn.on_request` does not check App Check itself (only callables do).
        if not config.REQUIRE_APP_CHECK.value:
            return
        token = req.headers.get("X-Firebase-AppCheck", "").strip()
        if not token:
            raise Unauthorized("App Check token missing")
        from firebase_admin import app_check

        try:
            app_check.verify_token(token)
        except Exception as exc:
            raise Unauthorized("App Check token invalid") from exc


class StaticAuthenticator:
    """Test double: a fixed identity (or none). With [invalid_token] any bearer token is
    rejected; with [app_check_ok] False every request fails App Check."""

    def __init__(self, info: AuthInfo | None = None, *, invalid_token: bool = False, app_check_ok: bool = True):
        self.info = info
        self.invalid_token = invalid_token
        self.app_check_ok = app_check_ok

    def optional(self, req) -> AuthInfo | None:
        if self.invalid_token and bearer_token(req):
            raise Unauthorized("Invalid Firebase ID token")
        return self.info

    def require(self, req) -> AuthInfo:
        info = self.optional(req)
        if info is None:
            raise Unauthorized("Sign in required (send a Firebase ID token)")
        return info

    def verify_app_check(self, req) -> None:
        if not self.app_check_ok:
            raise Unauthorized("App Check token missing")
