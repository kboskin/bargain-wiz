"""Helpers for the HTTPS functions: JSON responses, body parsing and the decorator that turns
handler results and errors into responses (one place for the status mapping)."""
import functools
import json
import logging
from collections.abc import Callable

from firebase_functions import https_fn

from core.errors import ApiError, BadRequest

logger = logging.getLogger("http")

Handler = Callable[[https_fn.Request], dict | https_fn.Response]


def json_response(body: dict, status: int = 200, headers: dict | None = None) -> https_fn.Response:
    return https_fn.Response(
        json.dumps(body, ensure_ascii=False),
        status=status,
        headers={"Content-Type": "application/json; charset=utf-8", **(headers or {})},
    )


def error_response(status: int, code: str, message: str) -> https_fn.Response:
    return json_response({"error": {"status": code, "message": message}}, status)


def json_body(req: https_fn.Request) -> dict:
    # force=True: accept JSON even when a client forgets the Content-Type header.
    body = req.get_json(force=True, silent=True)
    if not isinstance(body, dict):
        raise BadRequest("Body must be a JSON object")
    return body


def json_endpoint(*, methods: tuple[str, ...]) -> Callable[[Handler], Callable[[https_fn.Request], https_fn.Response]]:
    """Wrap an `https_fn.on_request` handler: checks the method, turns a returned dict into a
    JSON response, maps [ApiError]s to their status and answers anything else with a bare 500.

        @https_fn.on_request()
        @json_endpoint(methods=("POST",))
        def my_function(req): ...
    """

    def decorate(handler: Handler) -> Callable[[https_fn.Request], https_fn.Response]:
        @functools.wraps(handler)
        def wrapper(req: https_fn.Request) -> https_fn.Response:
            if req.method not in methods:
                return error_response(405, "METHOD_NOT_ALLOWED", f"Use {' or '.join(methods)}.")
            try:
                result = handler(req)
            except ApiError as exc:
                if exc.status >= 500:
                    logger.warning("%s %s → %s: %s", req.method, req.path, exc.code, exc)
                return error_response(exc.status, exc.code, exc.public_message)
            except Exception:
                logger.exception("%s %s: unhandled error", req.method, req.path)
                return error_response(500, "INTERNAL", "Unexpected error.")
            return result if isinstance(result, https_fn.Response) else json_response(result)

        return wrapper

    return decorate
