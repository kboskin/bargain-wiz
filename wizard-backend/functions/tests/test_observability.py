"""Structured logs, metrics, and the HTTP edge that ties them to a request."""

import asyncio
import json
import logging

import pytest
from flask import Flask, request

from core.errors import BadRequest, ConfigError, UpstreamError
from core.http.endpoint import JsonEndpoint
from core.observability import (
    CloudLoggingFormatter,
    ConsoleFormatter,
    HttpRequest,
    Invocation,
    LogMetrics,
    ModelCall,
    StructuredLogger,
    Telemetry,
)
from support import InMemoryMetrics

TRACE = "4bf92f3577b34da6a3ce929d0e0e4736"
HEADERS = {"X-Cloud-Trace-Context": f"{TRACE}/1;o=1"}


class Keep(logging.Handler):
    """Collects the records a logger emits, whatever the root logger is configured with."""

    def __init__(self):
        super().__init__()
        self.records: list[logging.LogRecord] = []

    def emit(self, record: logging.LogRecord) -> None:
        self.records.append(record)


def _record(log: StructuredLogger, message: str = "turn queued", **fields) -> logging.LogRecord:
    keep = Keep()
    log.logger.addHandler(keep)
    try:
        log.info(message, **fields)
    finally:
        log.logger.removeHandler(keep)
    return keep.records[0]


def _telemetry(headers=HEADERS) -> Telemetry:
    return Telemetry(
        Invocation.from_request("conversations", headers, "wizard-app-dev"), InMemoryMetrics()
    )


# ── the invocation ────────────────────────────────────────────────────────────


@pytest.mark.parametrize(
    ("headers", "expected"),
    [
        ({"X-Cloud-Trace-Context": f"{TRACE}/1;o=1"}, TRACE),
        ({"traceparent": f"00-{TRACE}-00f067aa0ba902b7-01"}, TRACE),
        ({"X-Cloud-Trace-Context": "junk"}, None),
        ({}, None),
    ],
)
def test_the_trace_comes_from_the_request_headers(headers, expected):
    assert Invocation.trace_id(headers) == expected


def test_an_invocation_names_its_function_and_its_trace():
    invocation = Invocation.from_request("conversations", HEADERS, "wizard-app-dev")
    assert invocation.log_fields() == {
        "function": "conversations",
        "logging.googleapis.com/trace": f"projects/wizard-app-dev/traces/{TRACE}",
    }
    assert Invocation.background("generate").log_fields() == {"function": "generate"}


# ── log lines ─────────────────────────────────────────────────────────────────


def test_a_cloud_log_line_is_one_json_entry_with_the_fields_and_the_trace():
    record = _record(_telemetry().logger("conversations"), uid="u1", images=2)
    entry = json.loads(CloudLoggingFormatter().format(record))
    assert (
        entry["severity"] == "INFO"
        and entry["message"] == "turn queued"
        and entry["logger"] == "conversations"
    )
    assert entry["uid"] == "u1" and entry["images"] == 2
    assert entry["function"] == "conversations"
    assert entry["logging.googleapis.com/trace"] == f"projects/wizard-app-dev/traces/{TRACE}"


def test_a_call_field_wins_over_a_bound_one():
    log = StructuredLogger.named("conversations", uid="bound").bind(kind="pro")
    assert StructuredLogger.fields_of(_record(log, uid="call")) == {"uid": "call", "kind": "pro"}


def test_the_console_line_reads_as_text_without_the_invocation_noise():
    record = _record(_telemetry().logger("conversations"), uid="u1", kind="pro")
    assert ConsoleFormatter().format(record) == "INFO conversations: turn queued uid=u1 kind=pro"


# ── metrics ───────────────────────────────────────────────────────────────────


def test_log_metrics_write_one_structured_entry_per_event_tagged_with_the_invocation():
    log = _telemetry().logger("metrics")
    keep = Keep()
    log.logger.addHandler(keep)
    event = ModelCall(
        provider="ollama",
        model="m",
        operation="reply",
        outcome="ok",
        latency_ms=12,
        prompt_tokens=5,
    )
    try:
        LogMetrics(log).emit(event)
    finally:
        log.logger.removeHandler(keep)
    [record] = keep.records
    assert record.getMessage() == "model_call"
    fields = StructuredLogger.fields_of(record)
    assert fields["metric"] == "model_call" and fields["function"] == "conversations"
    assert {k: fields[k] for k in event.model_dump()} == event.model_dump()


def test_telemetry_defaults_to_log_metrics():
    assert isinstance(Telemetry(Invocation.background("generate")).metrics, LogMetrics)


# ── the HTTP edge ─────────────────────────────────────────────────────────────


def _handle(handler, method="POST"):
    telemetry = Telemetry(Invocation.background("express_dealmaker"), InMemoryMetrics())

    async def run(req):
        return handler(req)

    with Flask(__name__).test_request_context("/x", method=method, json={}):
        res = asyncio.run(JsonEndpoint(("POST",), telemetry).handle(request, run))
    return (
        res.status_code,
        json.loads(res.get_data(as_text=True)),
        telemetry.metrics.of(HttpRequest),
    )


def test_a_returned_dict_is_a_json_200_and_a_request_metric():
    status, body, [metric] = _handle(lambda req: {"ok": True})
    assert (status, body) == (200, {"ok": True})
    assert (metric.function, metric.method, metric.status, metric.code) == (
        "express_dealmaker",
        "POST",
        200,
        None,
    )


def test_a_method_the_function_does_not_serve_is_a_405():
    status, body, [metric] = _handle(lambda req: {}, method="GET")
    assert (
        status == 405 and body["error"]["status"] == "METHOD_NOT_ALLOWED" and metric.status == 405
    )


@pytest.mark.parametrize(
    ("error", "status", "code", "message"),
    [
        (BadRequest("text: required"), 400, "INVALID_ARGUMENT", "text: required"),
        (
            UpstreamError("quota exhausted"),
            502,
            "UPSTREAM_ERROR",
            "The wizard could not answer right now. Try again.",
        ),
        (ConfigError("AI_MODEL: bad"), 500, "INTERNAL", "Unexpected error."),
        (RuntimeError("secret detail"), 500, "INTERNAL", "Unexpected error."),
    ],
)
def test_errors_map_to_a_status_and_never_leak_internals(error, status, code, message):
    def fail(req):
        raise error

    got_status, body, [metric] = _handle(fail)
    assert got_status == status and body["error"] == {"status": code, "message": message}
    assert metric.code == code


def test_a_failure_is_labelled_by_its_errors_reason():
    from core.errors import InvalidModelAnswer, ModelCallFailed, NotFound
    from core.observability import Outcome

    assert Outcome.of(ModelCallFailed("x")) == "call_failed"
    assert Outcome.of(InvalidModelAnswer("x")) == "invalid_answer"
    assert Outcome.of(ConfigError("x")) == "config_error"
    assert Outcome.of(NotFound("x")) == "not_found"
    assert Outcome.of(RuntimeError("x")) == Outcome.INTERNAL
