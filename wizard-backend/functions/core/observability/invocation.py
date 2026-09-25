"""The invocation a log line or a metric belongs to."""

import re
from collections.abc import Mapping
from typing import ClassVar, Self

from pydantic import BaseModel, ConfigDict


class Invocation(BaseModel):
    """Which function is running and, over HTTP, the trace the serving infrastructure put on
    the request. Every log line and metric of the invocation carries both, so Cloud Logging
    groups a request's lines under it."""

    model_config = ConfigDict(frozen=True)

    TRACE_ID: ClassVar[re.Pattern[str]] = re.compile(r"[0-9a-f]{32}")
    TRACE_FIELD: ClassVar[str] = "logging.googleapis.com/trace"

    function: str
    trace: str | None = None  # `projects/{project}/traces/{trace id}`

    @classmethod
    def from_request(cls, function: str, headers: Mapping[str, str], project_id: str) -> Self:
        trace_id = cls.trace_id(headers)
        trace = f"projects/{project_id}/traces/{trace_id}" if trace_id and project_id else None
        return cls(function=function, trace=trace)

    @classmethod
    def background(cls, function: str) -> Self:
        """A queue task or a schedule: no request, no trace."""
        return cls(function=function)

    @classmethod
    def trace_id(cls, headers: Mapping[str, str]) -> str | None:
        """`X-Cloud-Trace-Context: TRACE_ID/SPAN_ID;o=1`, else W3C `traceparent: 00-TRACE_ID-…`."""
        cloud = (headers.get("X-Cloud-Trace-Context") or "").split("/", 1)[0].strip().lower()
        if cls.TRACE_ID.fullmatch(cloud):
            return cloud
        parts = (headers.get("traceparent") or "").strip().lower().split("-")
        if len(parts) == 4 and cls.TRACE_ID.fullmatch(parts[1]):
            return parts[1]
        return None

    def log_fields(self) -> dict[str, str]:
        fields = {"function": self.function}
        if self.trace:
            fields[self.TRACE_FIELD] = self.trace
        return fields
