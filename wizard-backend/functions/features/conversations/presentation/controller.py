"""The `conversations` function: one URL, so the method and sub-path decide what a request is."""

from firebase_functions import https_fn

from core.auth.firebase import Authenticator
from core.errors import NotFound
from core.http.endpoint import JsonHttp

from ..domain.service import ConversationService


class ConversationsController:
    """Requires a Firebase ID token (anonymous users included) and, when switched on, App Check.

    POST   /conversations                  {type, text?, images?, profile}   → ids
    POST   /conversations/{cid}/messages   {text?, images?, profile}         → ids
    POST   /conversations/{cid}/options    {message_id?, profile}            → ids
    POST   /conversations/{cid}/redo       {message_id?, keyword?, profile}  → ids
    PATCH  /conversations/{cid}            {title?, status?, price_before?, price_after?, overrides?}
    GET    /conversations | /conversations/{cid}
    DELETE /conversations/{cid}            (archive)
    """

    def __init__(self, service: ConversationService, authenticator: Authenticator):
        self._service = service
        self._auth = authenticator

    async def handle(self, req: https_fn.Request) -> dict:
        await self._auth.verify_app_check(req)
        auth = await self._auth.require(req)
        body = JsonHttp.body(req) if req.method in ("POST", "PATCH") else {}
        segments = [s for s in req.path.split("/") if s]
        if segments and segments[0] == "conversations":
            segments = segments[1:]
        service = self._service
        match (req.method.upper(), segments):
            case ("POST", []):
                return await service.create(auth, body)
            case ("GET", []):
                return await service.index(auth)
            case ("GET", [cid]):
                return await service.get(auth, cid)
            case ("PATCH", [cid]):
                return await service.patch(auth, cid, body)
            case ("DELETE", [cid]):
                return await service.archive(auth, cid)
            case ("POST", [cid, "messages"]):
                return await service.send(auth, cid, body)
            case ("POST", [cid, "options"]):
                return await service.options(auth, cid, body)
            case ("POST", [cid, "redo"]):
                return await service.redo(auth, cid, body)
        raise NotFound(f"No route for {req.method} /{'/'.join(segments)}")
