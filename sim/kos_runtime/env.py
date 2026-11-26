from __future__ import annotations

from typing import Any


class Environment:
    """Nested, case-insensitive scopes."""

    def __init__(self, parent: Environment | None = None) -> None:
        self.parent = parent
        self._values: dict[str, Any] = {}
        # preserve first-seen casing for debugging
        self._names: dict[str, str] = {}

    def define(self, name: str, value: Any) -> None:
        key = name.lower()
        self._values[key] = value
        self._names[key] = name

    def set(self, name: str, value: Any) -> None:
        key = name.lower()
        env: Environment | None = self
        while env is not None:
            if key in env._values:
                env._values[key] = value
                return
            env = env.parent
        # kOS set without prior decl creates in current scope
        self.define(name, value)

    def get(self, name: str) -> Any:
        key = name.lower()
        env: Environment | None = self
        while env is not None:
            if key in env._values:
                return env._values[key]
            env = env.parent
        raise NameError(name)

    def has(self, name: str) -> bool:
        key = name.lower()
        env: Environment | None = self
        while env is not None:
            if key in env._values:
                return True
            env = env.parent
        return False

    def try_get(self, name: str, default: Any = None) -> Any:
        try:
            return self.get(name)
        except NameError:
            return default

    def child(self) -> Environment:
        return Environment(parent=self)
