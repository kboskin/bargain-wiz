"""Calling the functions the way Firebase does, with a container the test wired."""

import json

from firebase_functions import https_fn
from flask import Flask, request

import main
from container import Container
from core.observability import Invocation
from core.utils import RuntimeEnvironment

TEST_RUNTIME = RuntimeEnvironment(project_id="test-project")


class Wiring:
    """Stands in for `Container` in `main`: every invocation gets a container made with the
    same parts (stores, authenticator, metrics, dispatcher…); the model is whatever AI_MODEL
    says."""

    def __init__(self, **parts):
        self._parts = {"runtime": TEST_RUNTIME, **parts}

    def for_request(self, function: str, req: https_fn.Request) -> Container:
        return Container(
            Invocation.from_request(function, req.headers, TEST_RUNTIME.project_id), **self._parts
        )

    def for_background(self, function: str) -> Container:
        return Container(Invocation.background(function), **self._parts)


def install(monkeypatch, **parts) -> Container:
    """Wire `main` to [parts] and return a container with the same parts, for the test to use
    directly (the worker, the prompt builder…)."""
    wiring = Wiring(**parts)
    monkeypatch.setattr(main, "Container", wiring)
    return wiring.for_background("test")


def call(function, method: str, path: str = "/", body=None, headers: dict | None = None, **kwargs):
    """`function(request)` for one request → (status, decoded JSON body, headers)."""
    with Flask(__name__).test_request_context(
        path, method=method, json=body, headers=headers or {}, **kwargs
    ):
        res = function(request)
    return res.status_code, json.loads(res.get_data(as_text=True)), res.headers
