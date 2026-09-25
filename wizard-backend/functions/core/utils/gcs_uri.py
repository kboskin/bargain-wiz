"""A Cloud Storage object's address."""

from typing import ClassVar, Self

from pydantic import BaseModel, ConfigDict


class GcsUri(BaseModel):
    """`gs://bucket/path/to/object`, parsed."""

    model_config = ConfigDict(frozen=True)

    SCHEME: ClassVar[str] = "gs://"

    bucket: str
    path: str

    @classmethod
    def parse(cls, uri: str) -> Self:
        if not uri.startswith(cls.SCHEME):
            raise ValueError(f"not a gs:// URI: {uri!r}")
        bucket, _, path = uri.removeprefix(cls.SCHEME).partition("/")
        if not bucket or not path:
            raise ValueError(f"not a gs:// object URI: {uri!r}")
        return cls(bucket=bucket, path=path)

    def __str__(self) -> str:
        return f"{self.SCHEME}{self.bucket}/{self.path}"
