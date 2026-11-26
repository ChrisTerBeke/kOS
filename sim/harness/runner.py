from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from harness.assertions import InvariantLimits, OrbitTolerances, assert_invariants, assert_orbit
from kos_runtime.vm import VirtualMachine
from sim_host.host import SimHost, SimFault


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
) -> MissionResult:
    repo_root = repo_root.resolve()
    vehicle_yaml = vehicle_yaml or (repo_root / "sim" / "vehicles" / "f9_like.yaml")
    work = repo_root / "sim" / ".work" / mission_name
    if work.exists():
        import shutil

        shutil.rmtree(work)
    work.mkdir(parents=True, exist_ok=True)

    host = SimHost.from_vehicle_yaml(vehicle_yaml, archive_root=repo_root, work_root=work)
    # Copy programs onto flight computer volume like start.ks does
    samples: list[dict[str, Any]] = []
    vm = VirtualMachine(host)

    try:
        if host.path_exists("0:/boot/boot.ks"):
            vm.run_path("0:/boot/boot.ks")
        if inject_enter:
            # Enter key once mission is waiting for input
            host.push_terminal_char("\n")
        vm.run_path("0:/start.ks", args=[mission_name])
        # If start returns immediately after scheduling, drive until idle
        # Main loop uses wait 0.2 — VM should block cooperatively until finished.
        elapsed = 0.0
        while elapsed < timeout_sim_s and not vm.is_finished:
            host.advance(0.2)
            elapsed += 0.2
            if int(elapsed) % 10 == 0:
                samples.append(host.snapshot())
        snap = host.snapshot()
        samples.append(snap)
        return MissionResult(completed=vm.is_finished, snapshot=snap, samples=samples)
    except (SimFault, NotImplementedError, RuntimeError) as exc:
        snap = host.snapshot()
        return MissionResult(completed=False, snapshot=snap, error=str(exc), samples=samples)


def run_f9_test(repo_root: Path, **kwargs: Any) -> MissionResult:
    result = run_mission(repo_root, mission_name="f9_test", **kwargs)
    if result.error:
        raise AssertionError(f"mission error: {result.error}\n{result.snapshot}")
    assert result.completed, f"mission did not complete: {result.snapshot}"
    assert_orbit(result.snapshot)
    assert_invariants(result.snapshot)
    return result
