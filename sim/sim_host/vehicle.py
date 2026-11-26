from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import yaml


@dataclass
class EngineSpec:
    name: str
    thrust_asl_n: float
    thrust_vac_n: float
    isp_asl: float
    isp_vac: float
    ignition: bool = False
    flameout: bool = False

    def isp(self, pressure_pa: float, asl_pressure: float = 101325.0) -> float:
        if asl_pressure <= 0:
            return self.isp_vac
        t = max(0.0, min(1.0, pressure_pa / asl_pressure))
        return self.isp_vac * (1.0 - t) + self.isp_asl * t

    def thrust(self, pressure_pa: float, asl_pressure: float = 101325.0) -> float:
        if self.flameout or not self.ignition:
            return 0.0
        if asl_pressure <= 0:
            return self.thrust_vac_n
        t = max(0.0, min(1.0, pressure_pa / asl_pressure))
        return self.thrust_vac_n * (1.0 - t) + self.thrust_asl_n * t


@dataclass
class ModuleSpec:
    type: str
    name: str
    deployed: bool = False
    released: bool = False

    def has_event(self, event: str) -> bool:
        if self.type == "LaunchClamp" and event == "release clamp":
            return not self.released
        if self.type == "ModuleProceduralFairing" and event == "deploy":
            return not self.deployed
        return False

    def do_event(self, event: str) -> None:
        if self.type == "LaunchClamp" and event == "release clamp":
            self.released = True
        elif self.type == "ModuleProceduralFairing" and event == "deploy":
            self.deployed = True


@dataclass
class StageSpec:
    name: str
    dry_mass_kg: float
    fuel_mass_kg: float
    engines: list[EngineSpec] = field(default_factory=list)
    modules: list[ModuleSpec] = field(default_factory=list)
    active: bool = False
    separated: bool = False

    @property
    def mass(self) -> float:
        if self.separated:
            return 0.0
        return self.dry_mass_kg + self.fuel_mass_kg


@dataclass
class Vehicle:
    name: str
    latitude_deg: float
    longitude_deg: float
    pad_altitude_m: float
    reference_area_m2: float
    cd: float
    max_rate_deg_s: float
    lag_gain: float
    stages: list[StageSpec]
    stage_index: int = 0
    clamps_held: bool = True
    fairing_deploy_count: int = 0
    staging_event_count: int = 0

    @classmethod
    def from_yaml(cls, path: Path) -> Vehicle:
        data = yaml.safe_load(path.read_text())
        stages: list[StageSpec] = []
        for raw in data["stages"]:
            engines = [
                EngineSpec(
                    name=e["name"],
                    thrust_asl_n=float(e["thrust_asl_n"]),
                    thrust_vac_n=float(e["thrust_vac_n"]),
                    isp_asl=float(e["isp_asl"]),
                    isp_vac=float(e["isp_vac"]),
                )
                for e in raw.get("engines", [])
            ]
            modules = [
                ModuleSpec(type=m["type"], name=m["name"])
                for m in raw.get("modules", [])
            ]
            stages.append(
                StageSpec(
                    name=raw["name"],
                    dry_mass_kg=float(raw["dry_mass_kg"]),
                    fuel_mass_kg=float(raw["fuel_mass_kg"]),
                    engines=engines,
                    modules=modules,
                )
            )
        launch = data.get("launch", {})
        drag = data.get("drag", {})
        attitude = data.get("attitude", {})
        return cls(
            name=data.get("name", path.stem),
            latitude_deg=float(launch.get("latitude_deg", 0.0)),
            longitude_deg=float(launch.get("longitude_deg", 0.0)),
            pad_altitude_m=float(launch.get("altitude_m", 0.0)),
            reference_area_m2=float(drag.get("reference_area_m2", 10.0)),
            cd=float(drag.get("cd", 0.3)),
            max_rate_deg_s=float(attitude.get("max_rate_deg_s", 15.0)),
            lag_gain=float(attitude.get("lag_gain", 2.0)),
            stages=stages,
        )

    @property
    def current_stage(self) -> StageSpec:
        return self.stages[self.stage_index]

    def total_mass(self) -> float:
        return sum(s.mass for s in self.stages if not s.separated)

    def active_engines(self) -> list[EngineSpec]:
        if self.current_stage.separated:
            return []
        return [e for e in self.current_stage.engines if e.ignition and not e.flameout]

    def all_modules(self) -> list[ModuleSpec]:
        mods: list[ModuleSpec] = []
        for stage in self.stages:
            if not stage.separated:
                mods.extend(stage.modules)
        return mods

    def modules_named(self, name: str) -> list[ModuleSpec]:
        return [m for m in self.all_modules() if m.type == name]

    def available_thrust(self, pressure_pa: float) -> float:
        return sum(e.thrust(pressure_pa) for e in self.active_engines())

    def combined_isp(self, pressure_pa: float) -> float:
        engines = self.active_engines()
        thrust = self.available_thrust(pressure_pa)
        if thrust <= 0:
            return 0.0
        return sum(e.isp(pressure_pa) * e.thrust(pressure_pa) / thrust for e in engines)

    def ignite_current_engines(self) -> None:
        for engine in self.current_stage.engines:
            engine.ignition = True
            engine.flameout = False
        self.current_stage.active = True

    def release_clamps(self) -> None:
        for module in self.modules_named("LaunchClamp"):
            module.do_event("release clamp")
        self.clamps_held = False

    def deploy_fairings(self) -> None:
        for module in self.modules_named("ModuleProceduralFairing"):
            if module.has_event("deploy"):
                module.do_event("deploy")
                self.fairing_deploy_count += 1

    def stage(self) -> None:
        """kOS `stage.` — ignite if cold, else separate and activate next."""
        self.staging_event_count += 1
        current = self.current_stage
        lit = any(e.ignition for e in current.engines)
        if not lit:
            self.ignite_current_engines()
            return
        # Separate current stage and ignite next if present
        for engine in current.engines:
            engine.ignition = False
            engine.flameout = True
        current.separated = True
        current.fuel_mass_kg = 0.0
        if self.stage_index + 1 < len(self.stages):
            self.stage_index += 1
            self.ignite_current_engines()

    def burn_fuel(self, thrust_n: float, isp_s: float, dt: float, g0: float = 9.80665) -> None:
        if thrust_n <= 0 or isp_s <= 0 or dt <= 0:
            return
        mass_flow = thrust_n / (isp_s * g0)
        burned = mass_flow * dt
        stage = self.current_stage
        if burned >= stage.fuel_mass_kg:
            stage.fuel_mass_kg = 0.0
            for engine in stage.engines:
                if engine.ignition:
                    engine.flameout = True
        else:
            stage.fuel_mass_kg -= burned

    def to_dict(self) -> dict[str, Any]:
        return {
            "name": self.name,
            "stage_index": self.stage_index,
            "mass": self.total_mass(),
            "fuel": self.current_stage.fuel_mass_kg,
            "clamps_held": self.clamps_held,
            "fairing_deploy_count": self.fairing_deploy_count,
            "staging_event_count": self.staging_event_count,
        }
