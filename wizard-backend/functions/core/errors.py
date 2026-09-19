"""Client-facing errors and their HTTP mapping.

Raise these anywhere below the HTTP layer; `http.handle` turns them into
`{"error": {"status": <code>, "message": <text>}}` with the right status. Anything that is
not an [ApiError] is a bug and becomes a 500 without leaking details.
"""


class ApiError(Exception):
    status = 500
    code = "INTERNAL"

    @property
    def public_message(self) -> str:
        return str(self) or self.code


class BadRequest(ApiError, ValueError):
    """The request is malformed or fails validation → 400."""

    status = 400
    code = "INVALID_ARGUMENT"


class Unauthorized(ApiError):
    """Missing or invalid Firebase ID token / App Check token → 401."""

    status = 401
    code = "UNAUTHENTICATED"


class NotFound(ApiError, LookupError):
    """No such resource for this caller (also used instead of 403: no ownership oracle) → 404."""

    status = 404
    code = "NOT_FOUND"


class TurnInProgress(ApiError):
    """A wizard reply is still being generated for this conversation → 409."""

    status = 409
    code = "TURN_IN_PROGRESS"


class UpstreamError(ApiError):
    """The model call failed or returned something unusable → 502. The detail is logged, the
    client gets a fixed message."""

    status = 502
    code = "UPSTREAM_ERROR"

    @property
    def public_message(self) -> str:
        return "The wizard could not answer right now. Try again."
