from pathlib import Path

from harness.runner import run_f9_test

REPO = Path(__file__).resolve().parents[3]


def test_f9_test_reaches_target_orbit():
    result = run_f9_test(REPO, timeout_sim_s=2500.0, quiet=True)
    assert result.completed
    assert result.error is None
