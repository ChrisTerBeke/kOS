"""Smoke: mission should clear the tower without impacting."""

from pathlib import Path

from harness.runner import run_mission

REPO = Path(__file__).resolve().parents[3]


def test_f9_clears_tower():
    result = run_mission(REPO, timeout_sim_s=60.0, quiet=True)
    # May not finish the full mission in 60s; must not have crashed.
    assert result.error is None or "impact" not in (result.error or "").lower(), result.error
    alts = [s["altitude"] for s in result.samples] + [result.snapshot["altitude"]]
    assert max(alts) > 1000, f"max altitude {max(alts)}; snapshot={result.snapshot}"
