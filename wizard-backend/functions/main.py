"""Firebase Cloud Functions (2nd gen, Python) for Bargain Wiz.

- `lines_that_land`   GET   public content for the Lines tab            wizard-app/LINES_THAT_LAND.md
- `express_dealmaker` POST  screenshots/text → three lines (stateless)  wizard-app/AI_INTEGRATION.md
- `pro_deal_closer`   POST  chat history → reply or lines (stateless)   wizard-app/AI_INTEGRATION.md
- `profile`           GET|PATCH the user's profile document             wizard-app/PROFILE_SYNC.md
- `conversations`     backend-owned deal conversations (Firestore + Cloud Storage)
                                                                        wizard-app/CONVERSATIONS.md

Nothing is kept between requests: each function builds what it needs from the environment
(`config.py`) and the Admin SDK, which caches its own clients. Tests replace the constructors
imported below (`VertexGenerator`, `FirestoreProfileStore`, …) with fakes.
"""
import logging
from email.utils import format_datetime

from firebase_admin import initialize_app
from firebase_functions import https_fn, options

import config
from auth import FirebaseAuthenticator
from conversation_store import FirestoreConversationStore
from conversations import ConversationService, dispatch
from http_layer import json_body, json_endpoint, json_response
from lines_that_land_service import load_content, locales_of, new_template
from negotiation import (
    EXPRESS_SCHEMA,
    OPTIONS_SCHEMA,
    REPLY_SCHEMA,
    express_parts,
    express_result,
    options_result,
    parse_express_request,
    parse_pro_request,
    pro_parts,
    reply_result,
    system_prompt,
)
from user_profile import (
    FirestoreProfileStore,
    Identity,
    apply_patch,
    jsonable,
    read_profile,
    validate_installation_id,
)
from vertex import VertexGenerator

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


@https_fn.on_request(invoker="public", cors=CORS)
@json_endpoint(methods=("GET",))
def lines_that_land(req: https_fn.Request) -> https_fn.Response:
    """The current "Lines that land" categories in every locale; the app picks the language.
    No auth (public content), cacheable for the refresh interval."""
    content = load_content(new_template())
    hours = config.LINES_REFRESH_INTERVAL_HOURS.value
    max_age = hours * 3600
    return json_response(
        {
            "categories": content.categories,
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
    """The caller's profile document (`users/{uid}` or `users/inst_{installation_id}`).

    GET   ?installation_id=<uuid>   → the document, 404 when none exists yet.
    PATCH {installation_id?, preferences?, onboarding?, referral?, app?}
          → partial update (nested maps merge, null deletes a leaf); returns the document.
          With a Firebase ID token and an installation_id, a pending anonymous profile is
          folded into the uid profile first (signed-in values win).
    """
    auth = FirebaseAuthenticator().optional(req)
    if req.method == "GET":
        body: dict = {}
        installation_id = validate_installation_id(req.args.get("installation_id"))
    else:
        body = json_body(req)
        installation_id = validate_installation_id(body.get("installation_id"))
    identity = Identity(
        uid=auth.uid if auth else None,
        provider=auth.provider if auth else None,
        installation_id=installation_id,
    )
    store = FirestoreProfileStore()
    if req.method == "GET":
        return jsonable(read_profile(store, identity))
    doc = apply_patch(store, identity, body)
    logger.info("profile patch doc=%s sections=%s", identity.doc_id, sorted(k for k in body if k != "installation_id"))
    return jsonable(doc)


@https_fn.on_request(invoker="public", cors=CORS)
@json_endpoint(methods=("GET", "POST", "PATCH", "DELETE"))
def conversations(req: https_fn.Request) -> dict:
    """Deal conversations owned by the backend. Requires a Firebase ID token (anonymous users
    included); every write carries a client `request_id`.

    POST   /conversations                  {type, request_id, message?, …profile} → ids (+ express result)
    POST   /conversations/{cid}/messages   {request_id, text?, images?, …profile}  → ids
    POST   /conversations/{cid}/options    {request_id, message_id?, …profile}     → lines
    POST   /conversations/{cid}/redo       {request_id, message_id?, keyword?, …}  → ids
    PATCH  /conversations/{cid}            {title?, status?, price_before?, price_after?, vibe?}
    GET    /conversations | /conversations/{cid}
    DELETE /conversations | /conversations/{cid}
    """
    authenticator = FirebaseAuthenticator()
    authenticator.verify_app_check(req)
    auth = authenticator.require(req)
    body = json_body(req) if req.method in ("POST", "PATCH") else {}
    service = ConversationService(FirestoreConversationStore(), VertexGenerator())
    return dispatch(service, auth, req.method, req.path, body)
