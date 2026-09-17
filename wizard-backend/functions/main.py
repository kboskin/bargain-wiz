"""Firebase Cloud Functions (2nd gen, Python) for Bargain Wiz.

- `lines_that_land` — GET, public content for the Lines tab (below).
- `express_dealmaker` — POST screenshots (and/or text) → three negotiation lines (Gemini on Vertex AI).
- `pro_deal_closer` — POST chat history → coach reply or three lines (Gemini on Vertex AI).
Contracts: wizard-app/AI_INTEGRATION.md and wizard-app/LINES_THAT_LAND.md.

`lines_that_land` is a plain HTTPS function (https://firebase.google.com/docs/functions/http-events):
`GET .../lines_that_land` returns the current "Lines that land" categories for the app's
Lines tab as JSON, cacheable for the refresh interval. Content is read with the Admin SDK
from this project's **server** Remote Config template (parameter `lines_that_land_categories`)
and refreshed every LINES_REFRESH_INTERVAL_HOURS. Every text is a multilocale map
(`{"en": …, "es": …}`); the app picks the language. No query parameters.
Contract: wizard-app/LINES_THAT_LAND.md.
"""
import json
import logging
from email.utils import format_datetime

from firebase_admin import initialize_app
from firebase_functions import https_fn, options, params

from lines_that_land_service import LinesThatLandService, locales_of
from negotiation import (
    EXPRESS_SCHEMA,
    OPTIONS_SCHEMA,
    REPLY_SCHEMA,
    BadRequest,
    express_parts,
    express_result,
    options_result,
    parse_express_request,
    parse_pro_request,
    pro_parts,
    reply_result,
    system_prompt,
)
from runtime import Unauthorized, optional_uid
from vertex import JsonGenerator, UpstreamError, VertexGenerator

# Python's root logger defaults to WARNING; without this the request logs below never
# reach Cloud Logging.
logging.basicConfig(level=logging.INFO)
logging.getLogger().setLevel(logging.INFO)
logger = logging.getLogger("functions")

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


# ── AI negotiation functions ──────────────────────────────────────────────────

_generator: JsonGenerator | None = None


def get_generator() -> JsonGenerator:
    """Process-wide Gemini client (built on first use so imports stay cheap)."""
    global _generator
    if _generator is None:
        try:
            _generator = VertexGenerator()
        except UpstreamError:
            raise
        except Exception as exc:
            raise UpstreamError(f"Vertex AI client could not be created: {exc}") from exc
    return _generator


def _json_body(req: https_fn.Request) -> dict:
    # force=True: accept JSON even when a client forgets the Content-Type header.
    body = req.get_json(force=True, silent=True)
    if not isinstance(body, dict):
        raise BadRequest("Body must be a JSON object")
    return body


AI_FUNCTION_OPTIONS = {
    "region": "us-central1",
    "memory": options.MemoryOption.MB_512,
    "timeout_sec": 60,
    "max_instances": 20,
    "invoker": "public",
    "cors": options.CorsOptions(cors_origins="*", cors_methods=["post"]),
}


def _ai_call(req: https_fn.Request, handle) -> https_fn.Response:
    """Shared envelope: method check, optional auth, error mapping."""
    if req.method != "POST":
        return _error(405, "METHOD_NOT_ALLOWED", "Use POST with a JSON body.")
    try:
        uid = optional_uid(req)
        body = handle(_json_body(req), uid)
        return _json_response(body)
    except Unauthorized as exc:
        return _error(401, "UNAUTHENTICATED", str(exc))
    except BadRequest as exc:
        return _error(400, "INVALID_ARGUMENT", str(exc))
    except UpstreamError as exc:
        logger.warning("model call failed: %s", exc)
        return _error(502, "UPSTREAM_ERROR", "The wizard could not answer right now. Try again.")
    except ValueError as exc:  # unusable model output
        logger.warning("model output unusable: %s", exc)
        return _error(502, "UPSTREAM_ERROR", "The wizard gave an unusable answer. Try again.")
    except Exception:  # last resort, never leak internals
        logger.exception("unhandled error")
        return _error(500, "INTERNAL", "Unexpected error.")


@https_fn.on_request(**AI_FUNCTION_OPTIONS)
def express_dealmaker(req: https_fn.Request) -> https_fn.Response:
    """POST {images|text, keyword?, locale, vibe, push, marketplace?, deal_size?}
    → {"seeing": str, "lines": [{intent, text, why}], "model": str}."""

    def handle(body: dict, uid: str | None) -> dict:
        request = parse_express_request(body)
        generator = get_generator()
        raw = generator.generate_json(
            system=system_prompt(request.profile), parts=express_parts(request), schema=EXPRESS_SCHEMA
        )
        logger.info("express_dealmaker uid=%s images=%d text=%s", uid, len(request.images), bool(request.text))
        return {**express_result(raw), "model": generator.model}

    return _ai_call(req, handle)


@https_fn.on_request(**AI_FUNCTION_OPTIONS)
def pro_deal_closer(req: https_fn.Request) -> https_fn.Response:
    """POST {messages: [{role, text, images?}], mode: reply|options, regenerate?, locale, vibe, push, …}
    → reply mode {"reply": str, "model": str}; options mode {"lines": [...], "model": str}."""

    def handle(body: dict, uid: str | None) -> dict:
        request = parse_pro_request(body)
        generator = get_generator()
        schema = OPTIONS_SCHEMA if request.mode == "options" else REPLY_SCHEMA
        raw = generator.generate_json(system=system_prompt(request.profile), parts=pro_parts(request), schema=schema)
        logger.info("pro_deal_closer uid=%s mode=%s messages=%d", uid, request.mode, len(request.messages))
        result = options_result(raw) if request.mode == "options" else reply_result(raw)
        return {**result, "model": generator.model}

    return _ai_call(req, handle)
