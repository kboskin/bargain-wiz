"""A client for the running emulator suite, for the end-to-end tests (`tests/test_e2e.py`).

It calls the functions over HTTP the way the app does — an anonymous Auth-emulator user, its
ID token on every call — and reads what the backend wrote back through the same API. Nothing
here starts or stops an emulator: the suite is yours to run (the `local-stack` skill).
"""

import os
import time
from collections.abc import Callable

import httpx


class EmulatorSuite:
    """Where the emulators listen: `firebase.json`'s ports, `.firebaserc`'s project, and how
    long a generation may take (`E2E_PROJECT`, `E2E_HOST`, `E2E_TIMEOUT_SEC` override them)."""

    FUNCTIONS_PORT = 5001
    AUTH_PORT = 9099
    REGION = "us-central1"

    def __init__(self, *, project: str, host: str, timeout_sec: float):
        self.project = project
        self.host = host
        self.timeout_sec = timeout_sec

    @classmethod
    def from_env(cls) -> "EmulatorSuite":
        return cls(
            project=os.environ.get("E2E_PROJECT", "wizard-app-dev"),
            host=os.environ.get("E2E_HOST", "127.0.0.1"),
            timeout_sec=float(os.environ.get("E2E_TIMEOUT_SEC", "300")),
        )

    def function_url(self, name: str) -> str:
        return f"http://{self.host}:{self.FUNCTIONS_PORT}/{self.project}/{self.REGION}/{name}"

    @property
    def sign_up_url(self) -> str:
        # The Auth emulator accepts any API key.
        return (
            f"http://{self.host}:{self.AUTH_PORT}"
            "/identitytoolkit.googleapis.com/v1/accounts:signUp?key=e2e"
        )


class EmulatorUser:
    """One anonymous user, signed up against the Auth emulator, calling the functions."""

    POLL_INTERVAL_SEC = 1.0

    def __init__(self, suite: EmulatorSuite, http: httpx.Client, *, uid: str, id_token: str):
        self._suite = suite
        self._http = http
        self.uid = uid
        self._headers = {"Authorization": f"Bearer {id_token}"}

    @classmethod
    def sign_up(cls, suite: EmulatorSuite, http: httpx.Client) -> "EmulatorUser":
        response = http.post(suite.sign_up_url, json={"returnSecureToken": True})
        response.raise_for_status()
        account = response.json()
        return cls(suite, http, uid=account["localId"], id_token=account["idToken"])

    def call(
        self, method: str, function: str, path: str = "", body: dict | None = None
    ) -> httpx.Response:
        url = self._suite.function_url(function) + path
        return self._http.request(method, url, json=body, headers=self._headers)

    def conversation(self, cid: str) -> dict:
        response = self.call("GET", "conversations", f"/conversations/{cid}")
        assert response.status_code == 200, response.text
        return response.json()

    def wait_for(self, cid: str, ready: Callable[[dict], bool], what: str) -> dict:
        """Polls the conversation (with its messages) until [ready] holds — the way the app's
        listener sees the worker's writes land. Fails at once on a failed generation, with
        the error the backend recorded, and after `E2E_TIMEOUT_SEC` otherwise."""
        deadline = time.monotonic() + self._suite.timeout_sec
        while True:
            conversation = self.conversation(cid)
            if ready(conversation):
                return conversation
            if failure := self.failure(conversation):
                raise AssertionError(f"{what}: the generation failed: {failure}")
            if time.monotonic() > deadline:
                raise AssertionError(f"{what}: not there after {self._suite.timeout_sec:.0f}s")
            time.sleep(self.POLL_INTERVAL_SEC)

    @staticmethod
    def failure(conversation: dict) -> dict | None:
        for message in conversation.get("messages", []):
            if message.get("status") == "failed":
                return message.get("error")
            if message.get("options_error"):
                return message["options_error"]
        return conversation.get("last_error")

    @staticmethod
    def message(conversation: dict, mid: str) -> dict:
        return next(m for m in conversation["messages"] if m["id"] == mid)
