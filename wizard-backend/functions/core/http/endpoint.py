"""The HTTPS edge: JSON in and out, and one [JsonEndpoint] per function that owns the method
check, the error → status mapping and the request metric."""

import json
from collections.abc import Awaitable, Callable
from typing import ClassVar

from firebase_functions import https_fn, options

from core.errors import ApiError, BadRequest, ConfigError
from core.observability import HttpRequest, Stopwatch, Telemetry

Handler = Callable[[https_fn.Request], Awaitable[dict | https_fn.Response]]


class JsonHttp:
    """Reading a JSON body and writing a JSON response."""

    CONTENT_TYPE: ClassVar[str] = "application/json; charset=utf-8"

    @classmethod
    def response(
        cls, body: dict, status: int = 200, headers: dict | None = None
    ) -> https_fn.Response:
        return https_fn.Response(
            json.dumps(body, ensure_ascii=False),
            status=status,
            headers={"Content-Type": cls.CONTENT_TYPE, **(headers or {})},
        )

    @classmethod
    def error(cls, status: int, code: str, message: str) -> https_fn.Response:
        return cls.response({"error": {"status": code, "message": message}}, status)

    @staticmethod
    def body(req: https_fn.Request) -> dict:
        # force=True: accept JSON even when a client forgets the Content-Type header.
        body = req.get_json(force=True, silent=True)
        if not isinstance(body, dict):
            raise BadRequest("Body must be a JSON object")
        return body


class JsonEndpoint:
    """One `https_fn.on_request` function.

    [handle] answers a method it does not serve with a 405, turns a returned dict into a JSON
    response, maps an [ApiError] to its status and anything else to a bare 500, and emits one
    `http_request` metric per call — all through the invocation's [Telemetry], so every line
    carries the function and the request's trace.
    """

    CORS: ClassVar[options.CorsOptions] = options.CorsOptions(
        cors_origins="*", cors_methods=["get", "post", "patch", "delete"]
    )

    def __init__(self, methods: tuple[str, ...], telemetry: Telemetry):
        self._methods = methods
        self._telemetry = telemetry
        self._log = telemetry.logger("http")

    async def handle(self, req: https_fn.Request, handler: Handler) -> https_fn.Response:
        watch = Stopwatch()
        response, code = await self._respond(req, handler)
        self._telemetry.metrics.emit(
            HttpRequest(
                function=self._telemetry.invocation.function,
                method=req.method,
                status=response.status_code,
                code=code,
                latency_ms=watch.elapsed_ms,
            )
        )
        return response

    async def _respond(
        self, req: https_fn.Request, handler: Handler
    ) -> tuple[https_fn.Response, str | None]:
        if req.method not in self._methods:
            return JsonHttp.error(
                405, "METHOD_NOT_ALLOWED", f"Use {' or '.join(self._methods)}."
            ), "METHOD_NOT_ALLOWED"
        try:
            result = await handler(req)
        except ApiError as exc:
            if isinstance(exc, ConfigError):
                self._log.error("misconfigured", method=req.method, path=req.path, error=str(exc))
            elif exc.status >= 500:
                self._log.warning(
                    "request failed",
                    method=req.method,
                    path=req.path,
                    code=exc.code,
                    error=str(exc),
                )
            return JsonHttp.error(exc.status, exc.code, exc.public_message), exc.code
        except Exception:  # noqa: BLE001 - the edge: any bug becomes a logged, bare 500
            self._log.exception("unhandled error", method=req.method, path=req.path)
            return JsonHttp.error(500, "INTERNAL", "Unexpected error."), "INTERNAL"
        return (
            result if isinstance(result, https_fn.Response) else JsonHttp.response(result)
        ), None
