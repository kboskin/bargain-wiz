"""Runtime helpers shared by the functions: project id and optional Firebase Auth."""
import logging
import os

logger = logging.getLogger("runtime")


class Unauthorized(Exception):
    """A Firebase ID token was presented but is invalid → 401."""


def firebase_project_id() -> str:
    """Project id from firebase_admin, else the Cloud Functions runtime environment."""
    try:
        import firebase_admin

        project = firebase_admin.get_app().project_id
        if project:
            return str(project)
    except Exception as exc:  # noqa: BLE001 - no app / no credentials: fall through to env
        logger.debug("firebase_admin project id unavailable (%s); trying environment", exc)
    return os.environ.get("GCLOUD_PROJECT") or os.environ.get("GOOGLE_CLOUD_PROJECT") or ""


def optional_uid(req) -> str | None:
    """uid from an `Authorization: Bearer <Firebase ID token>` header, None when absent.

    Signed-out users may call the AI functions (the app allows skipping sign-in), so a
    missing token is fine; a present but invalid one is rejected.
    """
    header = req.headers.get("Authorization", "")
    if not header.lower().startswith("bearer "):
        return None
    token = header[7:].strip()
    if not token:
        return None
    from firebase_admin import auth

    try:
        return auth.verify_id_token(token).get("uid")
    except Exception as exc:
        raise Unauthorized("Invalid Firebase ID token") from exc
