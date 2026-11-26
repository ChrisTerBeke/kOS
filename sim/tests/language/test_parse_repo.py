from __future__ import annotations

from pathlib import Path

import pytest

from kos_runtime.parser import parse_script


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[3]


def _ks_files() -> list[Path]:
    root = _repo_root()
    files: list[Path] = []
    for folder in ("programs", "boot"):
        files.extend(sorted((root / folder).rglob("*.ks")))
    start = root / "start.ks"
    if start.exists():
        files.append(start)
    return files


@pytest.mark.parametrize("path", _ks_files(), ids=lambda p: str(p.relative_to(_repo_root())))
def test_parse_repo_ks(path: Path) -> None:
    source = path.read_text(encoding="utf-8")
    script = parse_script(source, filename=str(path))
    assert script.statements is not None
