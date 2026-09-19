"""Runtime helpers: which Firebase project this code runs in."""
import logging
import os

logger = logging.getLogger("runtime")


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
