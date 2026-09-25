"""`lines_that_land`: the Lines tab content in every locale, public and cacheable."""

from email.utils import format_datetime

from firebase_functions import https_fn

from core.config import LinesSettings
from core.http.endpoint import JsonHttp
from core.utils import JsonValue

from ..domain.service import LinesService


class LinesController:
    """No auth (public content). The app picks the language; the cache lifetime is the
    refresh interval, so a client never holds content older than one regeneration."""

    def __init__(self, service: LinesService, settings: LinesSettings):
        self._service = service
        self._settings = settings

    async def get(self, req: https_fn.Request) -> https_fn.Response:
        content = await self._service.current()
        hours = self._settings.refresh_interval_hours
        max_age = hours * 3600
        return JsonHttp.response(
            {
                "categories": content.categories_json(),
                "locales": content.locales(),
                "updated_at": JsonValue.timestamp(content.updated_at),
                "refresh_interval_hours": hours,
                "source": content.source,
            },
            headers={
                "Cache-Control": f"public, max-age={max_age}, s-maxage={max_age}",
                "Last-Modified": format_datetime(content.updated_at, usegmt=True),
            },
        )
