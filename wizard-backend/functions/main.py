"""Firebase Cloud Functions (2nd gen, Python) for Bargain Wiz.

`lines_that_land` is a plain HTTPS function (https://firebase.google.com/docs/functions/http-events):
`GET .../lines_that_land` returns the current "Lines that land" categories for the app's
Lines tab as JSON, cacheable for the refresh interval. Content is read with the Admin SDK
from this project's **server** Remote Config template (parameter `lines_that_land_categories`)
and refreshed every LINES_REFRESH_INTERVAL_HOURS. Every text is a multilocale map
(`{"en": …, "es": …}`); the app picks the language. No query parameters.
Contract: wizard-app/LINES_THAT_LAND.md.
"""
import json
from email.utils import format_datetime

from firebase_admin import initialize_app
from firebase_functions import https_fn, options, params

from lines_that_land_service import LinesThatLandService, locales_of

initialize_app()

REFRESH_INTERVAL_HOURS = params.IntParam(
    "LINES_REFRESH_INTERVAL_HOURS",
    default=24,
    description="How often the Lines that land content is refreshed (hours). Drives the "
    "function cache TTL, Cache-Control max-age and the app's on-device cache.",
)

_service: LinesThatLandService | None = None


def get_service() -> LinesThatLandService:
    """Process-wide service (Cloud Functions reuses a warm instance between requests)."""
    global _service
    if _service is None:
        _service = LinesThatLandService(REFRESH_INTERVAL_HOURS.value)
    return _service


def _json_response(body: dict, status: int = 200, headers: dict | None = None) -> https_fn.Response:
    return https_fn.Response(
        json.dumps(body, ensure_ascii=False),
        status=status,
        headers={"Content-Type": "application/json; charset=utf-8", **(headers or {})},
    )


def _error(status: int, code: str, message: str) -> https_fn.Response:
    return _json_response({"error": {"status": code, "message": message}}, status)


@https_fn.on_request(
    region="us-central1",
    memory=options.MemoryOption.MB_256,
    timeout_sec=15,
    max_instances=10,
    invoker="public",
    cors=options.CorsOptions(cors_origins="*", cors_methods=["get"]),
)
def lines_that_land(req: https_fn.Request) -> https_fn.Response:
    """GET → current "Lines that land" categories with every locale. No auth: public content."""
    if req.method != "GET":
        return _error(405, "METHOD_NOT_ALLOWED", "Use GET.")

    service = get_service()
    content = service.get()
    hours = service.refresh_interval_hours
    body = {
        "categories": content.categories,
        "locales": locales_of(content.categories),
        "updated_at": content.updated_at.isoformat(timespec="seconds").replace("+00:00", "Z"),
        "refresh_interval_hours": hours,
        "source": content.source,
    }
    return _json_response(
        body,
        headers={
            "Cache-Control": f"public, max-age={hours * 3600}, s-maxage={hours * 3600}",
            "Last-Modified": format_datetime(content.updated_at, usegmt=True),
        },
    )
