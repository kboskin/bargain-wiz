"""Firebase Cloud Functions (2nd gen, Python) for Bargain Wiz.

- `lines_that_land`   GET   public content for the Lines tab            wizard-app/LINES_THAT_LAND.md
- `express_dealmaker` POST  screenshots/text → three lines (stateless)  wizard-app/AI_INTEGRATION.md
- `pro_deal_closer`   POST  chat history → reply or lines (stateless)   wizard-app/AI_INTEGRATION.md
- `profile`           GET|PATCH the user's profile document             wizard-app/PROFILE_SYNC.md
- `conversations`     backend-owned deal conversations (Firestore + Cloud Storage)
                                                                        wizard-app/CONVERSATIONS.md
- `generate`          task queue running the model calls for `conversations`; its `RateLimits`
                      are the rate limiter and its `RetryConfig` the retry policy.
- `refresh_lines`     schedule that regenerates the Lines tab content with the same model.

Nothing is kept between requests: each function builds what it needs from the environment
(`config.py`) and the Admin SDK, which caches its own clients. Tests replace the constructors
imported below (`VertexGenerator`, `FirestoreProfileStore`, …) with fakes.
"""
import logging
import os
from email.utils import format_datetime

from firebase_admin import initialize_app
from firebase_functions import https_fn, options, scheduler_fn, tasks_fn

from core import config
from core.ai.vertex import VertexGenerator
from core.auth.firebase import FirebaseAuthenticator
from core.http.endpoint import json_body, json_endpoint, json_response
from core.serialization import jsonable
from features.conversations.data.dispatchers import CloudTasksDispatcher, InlineDispatcher
from features.conversations.data.store import FirestoreConversationStore
from features.conversations.domain.ports import Dispatcher
from features.conversations.domain.service import ConversationService
from features.conversations.presentation.routes import dispatch
from features.lines_that_land.data.store import FirestoreLinesStore
from features.lines_that_land.domain.content import categories_json, current, locales_of
from features.lines_that_land.domain.generation import generate_categories
from features.negotiation.domain.lines import (
    EXPRESS_SCHEMA,
    OPTIONS_SCHEMA,
    REPLY_SCHEMA,
    express_result,
    options_result,
    reply_result,
)
from features.negotiation.domain.prompts import express_parts, pro_parts, system_prompt
from features.negotiation.presentation.requests import parse_express_request, parse_pro_request
from features.profile.data.store import FirestoreProfileStore
from features.profile.domain.profile import Identity, apply_patch, read_profile

# Python's root logger defaults to WARNING; without this the request logs never reach Cloud Logging.
logging.basicConfig(level=logging.INFO)
logging.getLogger().setLevel(logging.INFO)
logger = logging.getLogger("functions")

initialize_app()

options.set_global_options(
    region="us-central1",
    memory=config.INSTANCE_MEMORY_MB,
    timeout_sec=config.REQUEST_TIMEOUT_SEC,
    max_instances=config.MAX_INSTANCES,
)

CORS = options.CorsOptions(cors_origins="*", cors_methods=["get", "post", "patch", "delete"])


def conversation_service() -> ConversationService:
    """A service wired for this request: Firestore, Gemini, and the queue that paces it."""
    return ConversationService(FirestoreConversationStore(), VertexGenerator(), _dispatcher())


def _dispatcher() -> Dispatcher:
    """Cloud Tasks in the cloud. The Functions emulator only has a Cloud Tasks host when the
    tasks emulator runs; without it we generate inline so local development still works."""
    if os.environ.get("FUNCTIONS_EMULATOR") == "true" and not os.environ.get("CLOUD_TASKS_EMULATOR_HOST"):
        logger.info("no Cloud Tasks emulator: generating inline")
        return InlineDispatcher(conversation_service)
    return CloudTasksDispatcher()


@https_fn.on_request(invoker="public", cors=CORS)
@json_endpoint(methods=("GET",))
def lines_that_land(req: https_fn.Request) -> https_fn.Response:
    """The current "Lines that land" categories in every locale; the app picks the language.
    No auth (public content), cacheable for the refresh interval."""
    content = current(FirestoreLinesStore())
    hours = config.LINES_REFRESH_INTERVAL_HOURS.value
    max_age = hours * 3600
    return json_response(
        {
            "categories": categories_json(content.categories),
            "locales": locales_of(content.categories),
            "updated_at": content.updated_at.isoformat(timespec="seconds").replace("+00:00", "Z"),
            "refresh_interval_hours": hours,
            "source": content.source,
        },
        headers={
            "Cache-Control": f"public, max-age={max_age}, s-maxage={max_age}",
            "Last-Modified": format_datetime(content.updated_at, usegmt=True),
        },
    )


@https_fn.on_request(invoker="public", cors=CORS)
@json_endpoint(methods=("POST",))
def express_dealmaker(req: https_fn.Request) -> dict:
    """{images|text, keyword?, …profile} → {"seeing", "lines": [{intent, text, why}], "model"}."""
    auth = FirebaseAuthenticator().optional(req)
    request = parse_express_request(json_body(req))
    generator = VertexGenerator()
    raw = generator.generate_json(system=system_prompt(request.profile), parts=express_parts(request), schema=EXPRESS_SCHEMA)
    logger.info("express_dealmaker uid=%s images=%d text=%s", auth and auth.uid, len(request.images), bool(request.text))
    return {**express_result(raw), "model": generator.model}


@https_fn.on_request(invoker="public", cors=CORS)
@json_endpoint(methods=("POST",))
def pro_deal_closer(req: https_fn.Request) -> dict:
    """{messages: [{role, text, images?}], mode: reply|options, regenerate?, …profile}
    → reply mode {"reply", "model"}; options mode {"lines", "model"}."""
    auth = FirebaseAuthenticator().optional(req)
    request = parse_pro_request(json_body(req))
    generator = VertexGenerator()
    schema = OPTIONS_SCHEMA if request.mode == "options" else REPLY_SCHEMA
    raw = generator.generate_json(system=system_prompt(request.profile), parts=pro_parts(request), schema=schema)
    logger.info("pro_deal_closer uid=%s mode=%s messages=%d", auth and auth.uid, request.mode, len(request.messages))
    result = options_result(raw) if request.mode == "options" else reply_result(raw)
    return {**result, "model": generator.model}


@https_fn.on_request(invoker="public", cors=CORS)
@json_endpoint(methods=("GET", "PATCH"))
def profile(req: https_fn.Request) -> dict:
    """The caller's profile document at `users/{uid}`. Requires a Firebase ID token
    (anonymous users included) — every install signs in before its first call.

    GET                 → the document, 404 when none exists yet.
    PATCH {preferences?, onboarding?, referral?, app?}
          → partial update (nested maps merge, null deletes a leaf); returns the document.
    """
    auth = FirebaseAuthenticator().require(req)
    identity = Identity(uid=auth.uid, provider=auth.provider)
    store = FirestoreProfileStore()
    if req.method == "GET":
        return jsonable(read_profile(store, identity))
    body = json_body(req)
    doc = apply_patch(store, identity, body)
    logger.info("profile patch doc=%s sections=%s", identity.doc_id, sorted(body))
    return jsonable(doc)


@https_fn.on_request(invoker="public", cors=CORS)
@json_endpoint(methods=("GET", "POST", "PATCH", "DELETE"))
def conversations(req: https_fn.Request) -> dict:
    """Deal conversations owned by the backend. Requires a Firebase ID token (anonymous users
    included). One turn is outstanding per conversation, so writes carry no client key.

    POST   /conversations                  {type, text?, images?, …profile}      → ids
    POST   /conversations/{cid}/messages   {text?, images?, …profile}            → ids
    POST   /conversations/{cid}/options    {message_id?, …profile}               → ids
    POST   /conversations/{cid}/redo       {message_id?, keyword?, …profile}     → ids

    Every write returns as soon as the turn is stored; the model call runs in the `generate`
    queue and the app reads the answer through its Firestore listener.
    PATCH  /conversations/{cid}            {title?, status?, price_before?, price_after?, vibe?}
    GET    /conversations | /conversations/{cid}
    DELETE /conversations | /conversations/{cid}
    """
    authenticator = FirebaseAuthenticator()
    authenticator.verify_app_check(req)
    auth = authenticator.require(req)
    body = json_body(req) if req.method in ("POST", "PATCH") else {}
    return dispatch(conversation_service(), auth, req.method, req.path, body)


@tasks_fn.on_task_dispatched(
    retry_config=options.RetryConfig(max_attempts=config.QUEUE_MAX_ATTEMPTS),
    rate_limits=options.RateLimits(
        max_concurrent_dispatches=config.QUEUE_MAX_CONCURRENT_DISPATCHES,
        max_dispatches_per_second=config.QUEUE_MAX_DISPATCHES_PER_SECOND,
    ),
)
def generate(req: tasks_fn.CallableRequest) -> None:
    """Runs one queued model call and completes the message it belongs to. Enqueued by
    `conversations`; the queue's rate limits pace every Gemini call in the project."""
    attempt = int(req.raw_request.headers.get("X-CloudTasks-TaskRetryCount") or 0)
    conversation_service().generate(req.data, attempt=attempt)


# A schedule is fixed at deploy time, so this reads the interval now rather than per call;
# change LINES_REFRESH_INTERVAL_HOURS in .env and redeploy to change the cadence.
@scheduler_fn.on_schedule(schedule=f"every {config.LINES_REFRESH_INTERVAL_HOURS.value} hours")
def refresh_lines(event: scheduler_fn.ScheduledEvent) -> None:
    """Regenerates the Lines tab content with Gemini (structured output, same generator as the
    chat) and stores it. A failure leaves the previous content in place; the next run retries."""
    generator = VertexGenerator()
    categories = generate_categories(generator)
    content = FirestoreLinesStore().write(categories, model=generator.model)
    logger.info(
        "lines regenerated: %d categories, %d lines",
        len(content.categories),
        sum(len(category.tips) for category in content.categories),
    )
