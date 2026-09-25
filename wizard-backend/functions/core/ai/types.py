"""What a model call is made of, independent of any provider's SDK."""

from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator


class TextPart(BaseModel):
    model_config = ConfigDict(frozen=True)

    type: Literal["text"] = "text"
    text: str


class ImagePart(BaseModel):
    """A screenshot: bytes the request carried, or the `gs://` URI of one already stored. A
    provider that reads Cloud Storage itself is handed the URI; for any other, the
    [ModelManager] downloads the object first."""

    model_config = ConfigDict(frozen=True)

    type: Literal["image"] = "image"
    mime_type: str
    data: bytes | None = None
    uri: str | None = None

    @model_validator(mode="after")
    def _one_source(self) -> "ImagePart":
        if (self.data is None) == (self.uri is None):
            raise ValueError("an image part has either data or a uri")
        return self


Part = Annotated[TextPart | ImagePart, Field(discriminator="type")]


class Prompt(BaseModel):
    """The system instruction and the user parts of one call, in the order the model reads them."""

    model_config = ConfigDict(frozen=True)

    system: str
    parts: list[Part]

    @property
    def images(self) -> list[ImagePart]:
        return [part for part in self.parts if isinstance(part, ImagePart)]

    @property
    def texts(self) -> list[str]:
        return [part.text for part in self.parts if isinstance(part, TextPart)]


class TokenUsage(BaseModel):
    """What a call cost, in the provider's own token counts. `cached_tokens` is the prompt
    prefix served from a cache (billed at a fraction); `thought_tokens` is thinking, billed as
    output."""

    model_config = ConfigDict(frozen=True)

    prompt_tokens: int = 0
    cached_tokens: int = 0
    output_tokens: int = 0
    thought_tokens: int = 0


class Completion(BaseModel):
    """What a provider returns: the answer's raw text, and the usage — None when the provider
    reported none, which is not the same as a call that cost nothing."""

    model_config = ConfigDict(frozen=True)

    text: str
    usage: TokenUsage | None = None


class Generated[Answer: BaseModel](BaseModel):
    """What [ModelManager.generate] returns: the validated answer, the model that wrote it,
    and what the call cost when the provider said."""

    model_config = ConfigDict(frozen=True)

    answer: Answer
    model: str
    usage: TokenUsage | None = None
