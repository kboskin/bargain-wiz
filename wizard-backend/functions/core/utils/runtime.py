"""What this process runs on."""

import os
from typing import Self

import firebase_admin
from pydantic import BaseModel, ConfigDict


class RuntimeEnvironment(BaseModel):
    """The project and the emulator flags, read from the environment once per invocation and
    handed to what needs them."""

    model_config = ConfigDict(frozen=True)

    project_id: str
    emulator: bool = False
    tasks_emulator: bool = False

    @classmethod
    def current(cls) -> Self:
        return cls(
            project_id=cls._project_id(),
            emulator=os.environ.get("FUNCTIONS_EMULATOR") == "true",
            tasks_emulator=bool(os.environ.get("CLOUD_TASKS_EMULATOR_HOST")),
        )

    @property
    def queues_inline(self) -> bool:
        """The emulator only has a Cloud Tasks host when a tasks emulator was started."""
        return self.emulator and not self.tasks_emulator

    @staticmethod
    def _project_id() -> str:
        """The project the Cloud Functions runtime (and the emulator) was given, else the Admin
        SDK's. The environment comes first because it is free, while the SDK may have to ask
        Application Default Credentials — a slow lookup off Google Cloud."""
        if project := os.environ.get("GCLOUD_PROJECT") or os.environ.get("GOOGLE_CLOUD_PROJECT"):
            return project
        try:
            return str(firebase_admin.get_app().project_id or "")
        except Exception:  # noqa: BLE001 - no default app, or no credentials to ask
            return ""
