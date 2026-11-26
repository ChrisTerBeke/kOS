from __future__ import annotations

import argparse
import json
from pathlib import Path

from harness.runner import run_mission


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description="Run a kOS mission in the offline simulator")
    parser.add_argument("mission", nargs="?", default="f9_test")
    parser.add_argument("--repo", type=Path, default=Path.cwd())
    parser.add_argument("--timeout", type=float, default=3600.0)
    args = parser.parse_args(argv)
    result = run_mission(args.repo, mission_name=args.mission, timeout_sim_s=args.timeout)
    print(json.dumps({"completed": result.completed, "error": result.error, "snapshot": result.snapshot}, indent=2))
    raise SystemExit(0 if result.completed and not result.error else 1)


if __name__ == "__main__":
    main()
