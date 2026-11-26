from __future__ import annotations

import math
import shutil
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Callable

from sim_host.kerbin import Kerbin
from sim_host.math3d import Vec3, heading_direction
from sim_host.physics import G0, PhysicsEngine
from sim_host.vehicle import EngineSpec, ModuleSpec, Vehicle


class SimFault(RuntimeError):
    pass


@dataclass
class Direction:
    vector: Vec3
    pitch: float = 0.0
    yaw: float = 0.0
    roll: float = 0.0

    @property
    def starvector(self) -> Vec3:
        # Approximate starboard as east when facing up
        return Vec3(1.0, 0.0, 0.0)


@dataclass
class GeoCoordinates:
    lat: float
    lng: float


@dataclass
class OrbitProxy:
    apoapsis: float
    periapsis: float
    eccentricity: float
    inclination: float
    semimajoraxis: float
    period: float = 0.0


@dataclass
class EngineProxy:
    _engine: EngineSpec

    @property
    def ignition(self) -> bool:
        return self._engine.ignition

    @property
    def flameout(self) -> bool:
        return self._engine.flameout

    @property
    def isp(self) -> float:
        return self._engine.isp_vac

    @property
    def available_thrust(self) -> float:
        return self._engine.thrust_vac_n if self._engine.ignition and not self._engine.flameout else 0.0

    @property
    def availablethrust(self) -> float:
        return self.available_thrust


@dataclass
class ModuleProxy:
    _module: ModuleSpec
    _on_event: Callable[[ModuleSpec, str], None]

    def has_event(self, name: str) -> bool:
        return self._module.has_event(name)

    def hasEvent(self, name: str) -> bool:  # noqa: N802
        return self.has_event(name)

    def do_event(self, name: str) -> None:
        self._on_event(self._module, name)

    def doEvent(self, name: str) -> None:  # noqa: N802
        self.do_event(name)


@dataclass
class VolumeFile:
    path: Path

    def writeln(self, text: str) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        with self.path.open("a", encoding="utf-8") as fh:
            fh.write(str(text) + "\n")


@dataclass
class Volume:
    root: Path

    def create(self, path: str) -> None:
        target = self._resolve(path)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text("", encoding="utf-8")

    def open(self, path: str) -> VolumeFile:
        return VolumeFile(self._resolve(path))

    def exists(self, path: str) -> bool:
        return self._resolve(path).exists()

    def _resolve(self, path: str) -> Path:
        clean = path.replace("\\", "/")
        if ":" in clean:
            # strip volume prefix like 0:/ or 1:/
            clean = clean.split(":", 1)[1]
        clean = clean.lstrip("/")
        return self.root / clean


@dataclass
class ShipProxy:
    _host: SimHost

    @property
    def altitude(self) -> float:
        return self._host.physics.altitude

    @property
    def apoapsis(self) -> float:
        return self._host.physics.orbit().apoapsis

    @property
    def periapsis(self) -> float:
        return self._host.physics.orbit().periapsis

    @property
    def mass(self) -> float:
        return self._host.vehicle.total_mass()

    @property
    def available_thrust(self) -> float:
        p = self._host.body.atm_pressure(self.altitude)
        return self._host.vehicle.available_thrust(p)

    @property
    def availableThrust(self) -> float:  # noqa: N802
        return self.available_thrust

    @property
    def maxthrust(self) -> float:
        return self.available_thrust

    @property
    def verticalspeed(self) -> float:
        up = self._host.physics.state.position.normalized()
        return self._host.physics.state.velocity.dot(up)

    @property
    def vertical_speed(self) -> float:
        return self.verticalspeed

    @property
    def groundspeed(self) -> float:
        up = self._host.physics.state.position.normalized()
        v = self._host.physics.surface_velocity()
        return (v - up * v.dot(up)).mag()

    @property
    def q(self) -> float:
        # kOS SHIP:Q is dynamic pressure in atmospheres (not Pascals).
        density = self._host.body.atm_density(self.altitude)
        speed = self._host.physics.state.velocity.mag()
        q_pa = 0.5 * density * speed * speed
        return q_pa / 101325.0

    @property
    def body(self) -> Kerbin:
        return self._host.body

    @property
    def orbit(self) -> OrbitProxy:
        o = self._host.physics.orbit()
        return OrbitProxy(
            o.apoapsis,
            o.periapsis,
            o.eccentricity,
            o.inclination,
            o.semimajoraxis,
            o.period,
        )

    @property
    def geoposition(self) -> GeoCoordinates:
        return GeoCoordinates(self._host.vehicle.latitude_deg, self._host.vehicle.longitude_deg)

    @property
    def geoPosition(self) -> GeoCoordinates:  # noqa: N802
        return self.geoposition

    @property
    def facing(self) -> Direction:
        return Direction(vector=self._host.physics.state.facing)

    @property
    def prograde(self) -> Direction:
        v = self._host.physics.state.velocity
        if v.mag() <= 1e-6:
            return Direction(vector=self._host.physics.state.position.normalized())
        return Direction(vector=v.normalized())

    @property
    def srfprograde(self) -> Direction:
        v = self._host.physics.surface_velocity()
        if v.mag() <= 1e-6:
            return Direction(vector=self._host.physics.state.position.normalized())
        return Direction(vector=v.normalized())

    @property
    def srfPrograde(self) -> Direction:  # noqa: N802
        return self.srfprograde

    @property
    def up(self) -> Direction:
        return Direction(vector=self._host.physics.state.position.normalized(), pitch=90.0)

    @property
    def north(self) -> Direction:
        from sim_host.math3d import local_basis

        _east, north, _up = local_basis(self._host.physics.state.position)
        return Direction(vector=north)

    @property
    def deltav(self) -> Any:
        return type("DeltaV", (), {"vacuum": self.deltav_vacuum})()

    @property
    def deltav_vacuum(self) -> float:
        isp = self._host.vehicle.combined_isp(0.0) or self._host.vehicle.current_stage.engines[0].isp_vac
        fuel = sum(s.fuel_mass_kg for s in self._host.vehicle.stages if not s.separated)
        mass = self.mass
        dry = mass - fuel
        if dry <= 0 or isp <= 0:
            return 0.0
        return isp * G0 * math.log(mass / dry)

    def engines(self) -> list[EngineProxy]:
        engines: list[EngineProxy] = []
        for stage in self._host.vehicle.stages:
            if not stage.separated:
                engines.extend(EngineProxy(e) for e in stage.engines)
        return engines

    def modules_named(self, name: str) -> list[ModuleProxy]:
        return [
            ModuleProxy(m, self._host._module_event)
            for m in self._host.vehicle.modules_named(name)
        ]

    def modulesNamed(self, name: str) -> list[ModuleProxy]:  # noqa: N802
        return self.modules_named(name)

    @property
    def unpacked(self) -> bool:
        return True

    @property
    def control(self) -> Any:
        host = self._host

        class Control:
            @property
            def neutralize(self) -> bool:
                return False

            @neutralize.setter
            def neutralize(self, value: bool) -> None:
                if value:
                    host.neutralize_controls()

            @property
            def pilotmainthrottle(self) -> float:
                return host.physics.state.throttle

            @pilotmainthrottle.setter
            def pilotmainthrottle(self, value: float) -> None:
                host.physics.state.throttle = float(value)

        return Control()


class SimHost:
    def __init__(
        self,
        vehicle: Vehicle,
        archive_root: Path,
        body: Kerbin | None = None,
        work_root: Path | None = None,
        quiet: bool = False,
    ) -> None:
        self.body = body or Kerbin()
        self.vehicle = vehicle
        self.physics = PhysicsEngine(self.body, vehicle)
        self.archive_root = archive_root.resolve()
        self.work_root = (
            work_root or (self.archive_root / "sim" / ".work" / "default")
        ).resolve()
        self.work_root.mkdir(parents=True, exist_ok=True)
        self.volumes = {
            0: Volume(self.archive_root),
            1: Volume(self.work_root / "flight"),
        }
        self.volumes[1].root.mkdir(parents=True, exist_ok=True)
        self._current_volume = 1
        self._throttle_lock: Any | None = None
        self._steering_lock: Any | None = None
        self._throttle_evaluator: Callable[[], float] | None = None
        self._steering_evaluator: Callable[[], Any] | None = None
        self._terminal: list[str] = []
        self._ship = ShipProxy(self)
        self.invariant_log: list[str] = []
        self.quiet = quiet

    def print(self, *args: Any, **kwargs: Any) -> None:  # noqa: A003
        if not self.quiet:
            print(*args, **kwargs)

    def hudtext(self, text: Any, *args: Any, **kwargs: Any) -> None:
        if not self.quiet:
            print(f"[hudtext] {text}")

    @classmethod
    def from_vehicle_yaml(
        cls,
        vehicle_path: Path,
        archive_root: Path,
        work_root: Path | None = None,
        quiet: bool = False,
    ) -> SimHost:
        vehicle = Vehicle.from_yaml(vehicle_path)
        return cls(
            vehicle=vehicle,
            archive_root=archive_root,
            work_root=work_root,
            quiet=quiet,
        )

    @property
    def ship(self) -> ShipProxy:
        return self._ship

    @property
    def time_seconds(self) -> float:
        return self.physics.state.time

    @property
    def mission_time(self) -> float:
        return self.physics.state.time - self.physics.state.mission_start

    def eta_apoapsis(self) -> float:
        return self.physics.orbit().eta_apoapsis

    def eta_periapsis(self) -> float:
        return self.physics.orbit().eta_periapsis

    def advance(self, dt: float) -> None:
        if self._throttle_evaluator is not None:
            self.physics.state.throttle = float(self._throttle_evaluator())
        elif self._throttle_lock is not None:
            self.physics.state.throttle = float(self._throttle_lock)
        if self._steering_evaluator is not None:
            steering = self._steering_evaluator()
            self._apply_steering(steering)
        self.physics.advance(dt)
        violations = self.physics.consume_violations()
        if violations:
            self.invariant_log.extend(violations)
            raise SimFault(f"physics fault: {violations}")

    def _apply_steering(self, steering: Any) -> None:
        vec = None
        if isinstance(steering, Direction):
            vec = steering.vector
        elif isinstance(steering, Vec3):
            vec = steering
        elif hasattr(steering, "vector"):
            vec = steering.vector
        elif hasattr(steering, "x") and hasattr(steering, "y") and hasattr(steering, "z"):
            vec = steering
        if vec is None:
            return
        self.physics.set_steering_target(Vec3(float(vec.x), float(vec.y), float(vec.z)))

    def set_throttle_lock(self, expression: Any | None) -> None:
        self._throttle_lock = expression

    def set_steering_lock(self, expression: Any | None) -> None:
        self._steering_lock = expression

    def set_throttle_evaluator(self, fn: Callable[[], float] | None) -> None:
        self._throttle_evaluator = fn

    def set_steering_evaluator(self, fn: Callable[[], Any] | None) -> None:
        self._steering_evaluator = fn

    def evaluate_throttle(self) -> float:
        if self._throttle_evaluator:
            return float(self._throttle_evaluator())
        return float(self.physics.state.throttle)

    def evaluate_steering(self) -> Any:
        if self._steering_evaluator:
            return self._steering_evaluator()
        return Direction(self.physics.state.facing)

    def set_throttle(self, value: float) -> None:
        self.physics.state.throttle = max(0.0, min(1.0, float(value)))

    def release_clamps(self) -> None:
        self.vehicle.release_clamps()

    def stage(self) -> None:
        self.vehicle.stage()

    def set_rcs(self, enabled: bool) -> None:
        self.physics.state.rcs = enabled

    def set_sas(self, enabled: bool) -> None:
        self.physics.state.sas = enabled

    def set_abort(self, enabled: bool) -> None:
        self.physics.state.abort = enabled

    def neutralize_controls(self) -> None:
        self._throttle_evaluator = None
        self._steering_evaluator = None
        self.physics.state.throttle = 0.0

    def volume(self, id: int) -> Volume:
        return self.volumes[id]

    def switch_to(self, volume: Volume) -> None:
        for vid, vol in self.volumes.items():
            if vol is volume or vol.root == volume.root:
                self._current_volume = vid
                return

    def resolve_path(self, path: str) -> str:
        raw = path.replace("\\", "/")
        if raw.startswith("0:/"):
            return str(self.volumes[0]._resolve(raw))
        if raw.startswith("1:/"):
            return str(self.volumes[1]._resolve(raw))
        # relative to current volume
        return str(self.volumes[self._current_volume]._resolve(raw))

    def read_script(self, path: str) -> str:
        resolved = Path(self.resolve_path(path))
        if not resolved.exists():
            # try .ks extension
            if not resolved.suffix:
                candidate = resolved.with_suffix(".ks")
                if candidate.exists():
                    resolved = candidate
        return resolved.read_text(encoding="utf-8")

    def path_exists(self, path: str) -> bool:
        p = Path(self.resolve_path(path))
        return p.exists() or p.with_suffix(".ks").exists()

    def copy_path(self, src: str, dst: str) -> None:
        src_p = Path(self.resolve_path(src))
        dst_p = Path(self.resolve_path(dst))
        if src_p.is_dir():
            if dst_p.exists():
                shutil.rmtree(dst_p)
            shutil.copytree(src_p, dst_p)
        else:
            dst_p.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src_p, dst_p)

    def delete_path(self, path: str) -> None:
        p = Path(self.resolve_path(path))
        if p.is_dir():
            shutil.rmtree(p, ignore_errors=True)
        elif p.exists():
            p.unlink()

    def push_terminal_char(self, ch: str) -> None:
        self._terminal.append(ch)

    def terminal_has_char(self) -> bool:
        return bool(self._terminal)

    def terminal_get_char(self) -> str:
        return self._terminal.pop(0)

    def _module_event(self, module: ModuleSpec, event: str) -> None:
        module.do_event(event)
        if module.type == "LaunchClamp" and event == "release clamp":
            if all(not m.has_event("release clamp") for m in self.vehicle.modules_named("LaunchClamp")):
                self.vehicle.clamps_held = False
        if module.type == "ModuleProceduralFairing" and event == "deploy":
            self.vehicle.fairing_deploy_count += 1

    def heading(self, dir_deg: float, pitch_deg: float) -> Direction:
        vec = heading_direction(dir_deg, pitch_deg, position=self.physics.state.position)
        return Direction(vector=vec, pitch=pitch_deg, yaw=dir_deg)

    def snapshot(self) -> dict[str, Any]:
        o = self.physics.orbit()
        return {
            "time": self.time_seconds,
            "altitude": self.physics.altitude,
            "apoapsis": o.apoapsis,
            "periapsis": o.periapsis,
            "eccentricity": o.eccentricity,
            "inclination": o.inclination,
            "throttle": self.physics.state.throttle,
            "vehicle": self.vehicle.to_dict(),
            "invariants": list(self.invariant_log),
        }
