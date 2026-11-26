"""KerboScript VM — filled in by runtime implementation."""

from __future__ import annotations

from typing import Any


class VirtualMachine:
    def __init__(self, host: Any) -> None:
        self.host = host
        self.is_finished = False

    def run_path(self, path: str, args: list[Any] | None = None) -> Any:
        raise NotImplementedError("VirtualMachine.run_path not implemented yet")
