"""Client-facing errors and their HTTP mapping.

Raise these anywhere below the HTTP layer; [core.http.endpoint.JsonEndpoint] turns them into
`{"error": {"status": <code>, "message": <text>}}` with the right status. Anything that is
not an [ApiError] is a bug and becomes a 500 without leaking details. Every error also names
its [reason], the outcome label its metric carries.
"""

from typing import ClassVar


class ApiError(Exception):
    status: ClassVar[int] = 500
    code: ClassVar[str] = "INTERNAL"
    reason: ClassVar[str] = "internal"

    @property
    def public_message(self) -> str:
        return str(self) or self.code


class BadRequest(ApiError, ValueError):
    """The request is malformed or fails validation → 400."""

    status = 400
    code = "INVALID_ARGUMENT"
    reason = "bad_request"


class Unauthorized(ApiError):
    """Missing or invalid Firebase ID token / App Check token → 401."""

    status = 401
    code = "UNAUTHENTICATED"
    reason = "unauthenticated"


class NotFound(ApiError, LookupError):
    """No such resource for this caller (also used instead of 403: no ownership oracle) → 404."""

    status = 404
    code = "NOT_FOUND"
    reason = "not_found"


class TurnInProgress(ApiError):
    """A wizard reply is still being generated for this conversation → 409."""

    status = 409
    code = "TURN_IN_PROGRESS"
    reason = "turn_in_progress"


class ConfigError(ApiError):
    """A param holds a value the code cannot use → 500. The detail names the variable and is
    logged; the client gets the same fixed message as any other bug."""

    status = 500
    code = "INTERNAL"
    reason = "config_error"

    @property
    def public_message(self) -> str:
        return "Unexpected error."


class UpstreamError(ApiError):
    """The model call failed or returned something unusable → 502. The detail is logged, the
    client gets a fixed message. [reason] labels the `model_call` metric."""

    status = 502
    code = "UPSTREAM_ERROR"
    reason = "upstream_error"

    @property
    def public_message(self) -> str:
        return "The wizard could not answer right now. Try again."


class ModelCallFailed(UpstreamError):
    """The provider could not be reached, refused the call or timed out."""

    reason = "call_failed"


class InvalidModelAnswer(UpstreamError):
    """The model answered, but not in the shape the call asked for."""

    reason = "invalid_answer"
