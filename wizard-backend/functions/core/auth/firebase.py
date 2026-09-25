"""Firebase Auth and App Check verification behind one interface, so controllers never touch
`firebase_admin` directly and tests inject identities instead of monkeypatching."""

import asyncio
from typing import ClassVar, Protocol

from firebase_functions import https_fn
from pydantic import BaseModel, ConfigDict

from core.config import SecuritySettings
from core.errors import Unauthorized


class AuthInfo(BaseModel):
    """Who is calling: the Firebase uid (anonymous users included) and how they signed in."""

    model_config = ConfigDict(frozen=True)

    uid: str
    provider: str | None = None


class Authenticator(Protocol):
    async def optional(self, req: https_fn.Request) -> AuthInfo | None:
        """Identity from the Authorization header, or None when absent."""

    async def require(self, req: https_fn.Request) -> AuthInfo:
        """Identity from the Authorization header; Unauthorized when absent."""

    async def verify_app_check(self, req: https_fn.Request) -> None:
        """Unauthorized when App Check is enforced and the token is missing or invalid."""


class FirebaseAuthenticator:
    """Verifies Firebase ID tokens; anonymous users are first-class (every install has one).
    A token that is present but invalid is always rejected. The Admin SDK verifies
    synchronously (and may fetch Google's signing keys), so verification runs on a thread."""

    APP_CHECK_HEADER: ClassVar[str] = "X-Firebase-AppCheck"
    SIGN_IN_REQUIRED: ClassVar[str] = "Sign in required (send a Firebase ID token)"

    def __init__(self, security: SecuritySettings):
        self._security = security

    @staticmethod
    def bearer_token(req: https_fn.Request) -> str | None:
        header = req.headers.get("Authorization", "")
        if not header.lower().startswith("bearer "):
            return None
        return header[7:].strip() or None

    async def optional(self, req: https_fn.Request) -> AuthInfo | None:
        token = self.bearer_token(req)
        if token is None:
            return None
        # Imported on first use: firebase_admin.auth adds ~0.15 s to a cold start, and the
        # public Lines endpoint never verifies a token.
        from firebase_admin import auth as firebase_auth

        try:
            claims = await asyncio.to_thread(firebase_auth.verify_id_token, token)
        except Exception as exc:
            raise Unauthorized("Invalid Firebase ID token") from exc
        provider = (claims.get("firebase") or {}).get("sign_in_provider")
        return AuthInfo(uid=claims["uid"], provider=provider)

    async def require(self, req: https_fn.Request) -> AuthInfo:
        info = await self.optional(req)
        if info is None:
            raise Unauthorized(self.SIGN_IN_REQUIRED)
        return info

    async def verify_app_check(self, req: https_fn.Request) -> None:
        # `https_fn.on_request` does not check App Check itself (only callables do).
        if not self._security.require_app_check:
            return
        token = req.headers.get(self.APP_CHECK_HEADER, "").strip()
        if not token:
            raise Unauthorized("App Check token missing")
        from firebase_admin import app_check

        try:
            await asyncio.to_thread(app_check.verify_token, token)
        except Exception as exc:
            raise Unauthorized("App Check token invalid") from exc
