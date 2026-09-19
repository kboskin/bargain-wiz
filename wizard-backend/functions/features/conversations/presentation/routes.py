"""One Cloud Function has one URL, so the sub-path decides what a request means."""
from core.auth.firebase import AuthInfo
from core.errors import NotFound

from ..domain.service import ConversationService


def dispatch(service: ConversationService, auth: AuthInfo, method: str, path: str, body: dict) -> dict:
    """The payload for `method path` under the `conversations` function (NotFound otherwise).
    A Cloud Function has one URL; the sub-path is matched here."""
    segments = [s for s in path.split("/") if s]
    if segments and segments[0] == "conversations":
        segments = segments[1:]
    match (method.upper(), segments):
        case ("POST", []):
            return service.create(auth, body)
        case ("GET", []):
            return service.index(auth)
        case ("GET", [cid]):
            return service.get(auth, cid)
        case ("PATCH", [cid]):
            return service.patch(auth, cid, body)
        case ("DELETE", [cid]):
            return service.archive(auth, cid)
        case ("POST", [cid, "messages"]):
            return service.send(auth, cid, body)
        case ("POST", [cid, "options"]):
            return service.options(auth, cid, body)
        case ("POST", [cid, "redo"]):
            return service.redo(auth, cid, body)
    raise NotFound(f"No route for {method} /{'/'.join(segments)}")
