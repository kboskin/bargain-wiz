"""Firebase Cloud Functions (2nd gen, Python) for Bargain Wiz — entry points only.

- `lines_that_land`   GET   public content for the Lines tab            wizard-app/LINES_THAT_LAND.md
- `express_dealmaker` POST  screenshots/text → three lines (stateless)  wizard-app/AI_INTEGRATION.md
- `pro_deal_closer`   POST  chat history → reply or lines (stateless)   wizard-app/AI_INTEGRATION.md
- `profile`           GET|PATCH the user's profile document             wizard-app/PROFILE_SYNC.md
- `conversations`     backend-owned deal conversations (Firestore + Cloud Storage)
                                                                        wizard-app/CONVERSATIONS.md
- `generate`          task queue running the model calls for `conversations`; its `RateLimits`
                      are the rate limiter and its `RetryConfig` the retry policy.
- `refresh_lines`     schedule that regenerates the Lines tab content with the same model.

The Firebase CLI discovers functions as decorated module-level callables, so this is the one
module that has them. Firebase calls them synchronously; each makes a [Container] for its
invocation and runs it on an event loop of its own (`asyncio.run`), handing the request to the
feature module that serves it (`container.py`). Nothing is kept between requests. The
decorators take the params themselves (`Section.param`), so the deploy manifest carries them.
Tests replace [Container] with a factory wired to in-memory stores.
"""

import asyncio

from firebase_admin import initialize_app
from firebase_functions import https_fn, options, scheduler_fn, tasks_fn

from container import Container
from core.config import LinesSettings, QueueSettings, RuntimeSettings
from core.http.endpoint import JsonEndpoint
from core.observability import LoggingSetup
from core.utils import RuntimeEnvironment

# Process setup, once per instance: the SDK's default app, and where log lines go.
initialize_app()
LoggingSetup.configure(RuntimeEnvironment.current())

options.set_global_options(
    region="us-central1",
    memory=RuntimeSettings.param("memory_mb"),
    timeout_sec=RuntimeSettings.param("timeout_sec"),
    max_instances=RuntimeSettings.param("max_instances"),
)


@https_fn.on_request(invoker="public", cors=JsonEndpoint.CORS)
def lines_that_land(req: https_fn.Request) -> https_fn.Response:
    app = Container.for_request("lines_that_land", req)
    return asyncio.run(app.serve(req, ("GET",), lambda c: c.lines.controller.get))


@https_fn.on_request(invoker="public", cors=JsonEndpoint.CORS)
def express_dealmaker(req: https_fn.Request) -> https_fn.Response:
    app = Container.for_request("express_dealmaker", req)
    return asyncio.run(app.serve(req, ("POST",), lambda c: c.negotiation.controller.express))


@https_fn.on_request(invoker="public", cors=JsonEndpoint.CORS)
def pro_deal_closer(req: https_fn.Request) -> https_fn.Response:
    app = Container.for_request("pro_deal_closer", req)
    return asyncio.run(app.serve(req, ("POST",), lambda c: c.negotiation.controller.pro))


@https_fn.on_request(invoker="public", cors=JsonEndpoint.CORS)
def profile(req: https_fn.Request) -> https_fn.Response:
    app = Container.for_request("profile", req)
    return asyncio.run(app.serve(req, ("GET", "PATCH"), lambda c: c.profile.controller.handle))


@https_fn.on_request(invoker="public", cors=JsonEndpoint.CORS)
def conversations(req: https_fn.Request) -> https_fn.Response:
    app = Container.for_request("conversations", req)
    methods = ("GET", "POST", "PATCH", "DELETE")
    return asyncio.run(app.serve(req, methods, lambda c: c.conversations.controller.handle))


@tasks_fn.on_task_dispatched(
    retry_config=options.RetryConfig(max_attempts=QueueSettings.param("max_attempts")),
    rate_limits=options.RateLimits(
        max_concurrent_dispatches=QueueSettings.param("max_concurrent_dispatches"),
        max_dispatches_per_second=QueueSettings.param("max_dispatches_per_second"),
    ),
)
def generate(req: tasks_fn.CallableRequest) -> None:
    """One queued model call. Enqueued by `conversations`; the queue's rate limits pace every
    model call in the project."""
    attempt = int(req.raw_request.headers.get("X-CloudTasks-TaskRetryCount") or 0)
    app = Container.for_background("generate")
    asyncio.run(app.run(lambda c: c.conversations.worker.run(req.data, attempt=attempt)))


# A schedule is fixed at deploy time, so this reads the interval now rather than per call;
# change LINES_REFRESH_INTERVAL_HOURS in .env and redeploy to change the cadence.
@scheduler_fn.on_schedule(
    schedule=f"every {LinesSettings.param('refresh_interval_hours').value} hours"
)
def refresh_lines(event: scheduler_fn.ScheduledEvent) -> None:
    """Regenerates the Lines tab content. A failure leaves the previous content in place; the
    next run retries."""
    app = Container.for_background("refresh_lines")
    asyncio.run(app.run(lambda c: c.lines.generator.refresh()))
