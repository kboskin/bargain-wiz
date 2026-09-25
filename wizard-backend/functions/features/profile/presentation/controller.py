"""`profile`: the caller's profile document at `users/{uid}`."""

from firebase_functions import https_fn

from core.auth.firebase import Authenticator
from core.http.endpoint import JsonHttp
from core.utils import JsonValue

from ..domain.service import ProfileService


class ProfileController:
    """Requires a Firebase ID token (anonymous users included) — every install signs in before
    its first call.

    GET                 → the document, 404 when none exists yet.
    PATCH {preferences?, onboarding_status?, referral?, app?}
          → partial update (nested maps merge, null deletes a leaf); returns the document.
            `referral.code` is write-once: a code sent over one already recorded is dropped.
    """

    def __init__(self, service: ProfileService, authenticator: Authenticator):
        self._service = service
        self._auth = authenticator

    async def handle(self, req: https_fn.Request) -> dict:
        auth = await self._auth.require(req)
        if req.method == "GET":
            return JsonValue.of(await self._service.read(auth))
        return JsonValue.of(await self._service.patch(auth, JsonHttp.body(req)))
