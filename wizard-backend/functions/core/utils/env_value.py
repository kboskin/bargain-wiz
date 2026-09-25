"""How a raw environment string becomes a setting, for pydantic `BeforeValidator`s."""


class EnvValue:
    @staticmethod
    def optional(value: object) -> object:
        """An empty variable means "not set": the code then sends nothing and the provider
        decides. A set one is trimmed and lower-cased (choices are case-insensitive)."""
        if isinstance(value, str):
            value = value.strip()
            return value.lower() if value else None
        return value

    @staticmethod
    def optional_text(value: object) -> object:
        """Like [optional], with the case kept."""
        if isinstance(value, str):
            return value.strip() or None
        return value

    @staticmethod
    def csv(value: object) -> object:
        if isinstance(value, str):
            return tuple(part.strip() for part in value.split(",") if part.strip())
        return value

    @staticmethod
    def base_url(value: object) -> object:
        return value.strip().rstrip("/") if isinstance(value, str) else value
