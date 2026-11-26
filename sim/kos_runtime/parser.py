"""KerboScript parser — filled in by runtime implementation."""

from __future__ import annotations

from kos_runtime.ast_nodes import Script


def parse_script(source: str, filename: str = "<string>") -> Script:
    raise NotImplementedError("parser not implemented yet")
