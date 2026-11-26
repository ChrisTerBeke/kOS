from __future__ import annotations

from dataclasses import dataclass
from typing import Any


@dataclass
class OrbitTolerances:
    target_altitude_m: float = 140_000.0
    altitude_tol_m: float = 5_000.0
    target_inclination_deg: float = 25.0
    inclination_tol_deg: float = 2.0
    max_eccentricity: float = 0.05


@dataclass
class InvariantLimits:
    min_altitude_m: float = -1.0
    min_throttle: float = 0.0
    max_throttle: float = 1.0
    max_fairing_deploys: int = 1
    min_staging_events: int = 1
    max_staging_events: int = 8


def assert_orbit(snapshot: dict[str, Any], tol: OrbitTolerances | None = None) -> None:
    tol = tol or OrbitTolerances()
    apo = float(snapshot["apoapsis"])
    peri = float(snapshot["periapsis"])
    ecc = float(snapshot["eccentricity"])
    inc = float(snapshot["inclination"])
    assert abs(apo - tol.target_altitude_m) <= tol.altitude_tol_m, f"apoapsis={apo}"
    assert abs(peri - tol.target_altitude_m) <= tol.altitude_tol_m, f"periapsis={peri}"
    assert ecc <= tol.max_eccentricity, f"eccentricity={ecc}"
    assert abs(inc - tol.target_inclination_deg) <= tol.inclination_tol_deg, f"inclination={inc}"


def assert_invariants(snapshot: dict[str, Any], limits: InvariantLimits | None = None) -> None:
    limits = limits or InvariantLimits()
    assert snapshot["altitude"] >= limits.min_altitude_m
    throttle = float(snapshot["throttle"])
    assert limits.min_throttle <= throttle <= limits.max_throttle
    vehicle = snapshot["vehicle"]
    assert vehicle["fairing_deploy_count"] <= limits.max_fairing_deploys
    staging = vehicle["staging_event_count"]
    assert limits.min_staging_events <= staging <= limits.max_staging_events
    assert not snapshot.get("invariants"), snapshot.get("invariants")
