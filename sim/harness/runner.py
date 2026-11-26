from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from harness.assertions import assert_invariants, assert_orbit
from kos_runtime.vm import VirtualMachine
from sim_host.host import SimFault, SimHost


@dataclass
class MissionResult:
    completed: bool
    snapshot: dict[str, Any]
    error: str | None = None
    samples: list[dict[str, Any]] = field(default_factory=list)


def run_mission(
    repo_root: Path,
    mission_name: str = "f9_test",
    vehicle_yaml: Path | None = None,
    timeout_sim_s: float = 3600.0,
    inject_enter: bool = True,
    quiet: bool = True,
) -> MissionResult:
    """Boot archive and run ``start(mission_name)``.

    The VM cooperatively advances simulated time on every ``wait``, so the
    mission runs inside ``run_path`` until the main loop exits or a fault/timeout
    occurs.
    """
    repo_root = repo_root.resolve()
    vehicle_yaml = vehicle_yaml or (repo_root / "sim" / "vehicles" / "f9_like.yaml")
    work = repo_root / "sim" / ".work" / mission_name
    if work.exists():
        import shutil

        shutil.rmtree(work)
    work.mkdir(parents=True, exist_ok=True)

    host = SimHost.from_vehicle_yaml(
        vehicle_yaml, archive_root=repo_root, work_root=work, quiet=quiet
    )
    samples: list[dict[str, Any]] = []
    vm = VirtualMachine(host)
    # Soft wall: stop advancing once host clock exceeds timeout.
    max_time = host.time_seconds + timeout_sim_s
    original_advance = host.advance

    def guarded_advance(dt: float) -> None:
        if host.time_seconds >= max_time:
            raise TimeoutError(f"sim timeout at t={host.time_seconds:.1f}s")
        original_advance(dt)
        if int(host.time_seconds) % 30 == 0:
            snap = host.snapshot()
            if not samples or samples[-1].get("time") != snap.get("time"):
                samples.append(snap)

    host.advance = guarded_advance  # type: ignore[method-assign]

    try:
        if host.path_exists("0:/boot/boot.ks"):
            vm.run_path("0:/boot/boot.ks")
        if inject_enter:
            # kOS Enter — InputController compares against terminal:input:enter
            host.push_terminal_char("\r")
            host.push_terminal_char("\n")
        vm.run_path("0:/start.ks", args=[mission_name])
        snap = host.snapshot()
        samples.append(snap)
        return MissionResult(completed=True, snapshot=snap, samples=samples)
    except (SimFault, NotImplementedError, RuntimeError, TimeoutError) as exc:
        snap = host.snapshot()
        samples.append(snap)
        return MissionResult(completed=False, snapshot=snap, error=str(exc), samples=samples)


def run_f9_test(repo_root: Path, **kwargs: Any) -> MissionResult:
    result = run_mission(repo_root, mission_name="f9_test", **kwargs)
    if result.error:
        raise AssertionError(f"mission error: {result.error}\n{result.snapshot}")
    assert result.completed, f"mission did not complete: {result.snapshot}"
    assert_orbit(result.snapshot)
    assert_invariants(result.snapshot)
    return result
