from __future__ import annotations

import math
from dataclasses import dataclass

from sim_host.kerbin import Kerbin
from sim_host.math3d import Vec3, heading_direction, local_basis
from sim_host.vehicle import Vehicle

G0 = 9.80665


@dataclass
class OrbitElements:
    apoapsis: float
    periapsis: float
    eccentricity: float
    inclination: float
    semimajoraxis: float
    eta_apoapsis: float
    eta_periapsis: float
    period: float


def orbital_elements(r: Vec3, v: Vec3, body: Kerbin) -> OrbitElements:
    mu = body.mu
    r_mag = r.mag()
    v_mag = v.mag()
    h = r.cross(v)
    h_mag = h.mag()
    incl = 0.0 if h_mag <= 0 else math.degrees(math.acos(max(-1.0, min(1.0, h.z / h_mag))))
    # eccentricity vector
    e_vec = (v.cross(h) / mu) - (r / r_mag)
    ecc = e_vec.mag()
    energy = v_mag * v_mag / 2.0 - mu / r_mag
    if abs(energy) < 1e-12:
        sma = float("inf")
    else:
        sma = -mu / (2.0 * energy)
    if math.isfinite(sma) and sma > 0:
        apo_r = sma * (1.0 + ecc)
        peri_r = sma * (1.0 - ecc)
    else:
        apo_r = r_mag
        peri_r = r_mag
    apoapsis = max(0.0, apo_r - body.radius)
    periapsis = peri_r - body.radius
    # Approximate ETAs using period and true anomaly proxy
    if math.isfinite(sma) and sma > 0 and ecc < 1.0:
        period = 2.0 * math.pi * math.sqrt(sma**3 / mu)
        vr = v.dot(r.normalized())
        if apo_r > peri_r and ecc > 1e-8:
            cos_nu = max(-1.0, min(1.0, ((sma * (1 - ecc * ecc) / r_mag) - 1.0) / ecc))
            nu = math.acos(cos_nu)
            if vr < 0:
                nu = 2 * math.pi - nu
            ea = 2 * math.atan(
                math.sqrt((1 - ecc) / (1 + ecc + 1e-15)) * math.tan(nu / 2.0)
            )
            ma = ea - ecc * math.sin(ea)
            if ma < 0:
                ma += 2 * math.pi
            eta_pe = ((2 * math.pi - ma) % (2 * math.pi)) / (2 * math.pi) * period
            eta_ap = ((math.pi - ma) % (2 * math.pi)) / (2 * math.pi) * period
        else:
            # Near-circular: treat "apo" as half-period ahead from an arbitrary clock
            eta_ap = period / 2.0
            eta_pe = period
    else:
        period = float("inf")
        eta_ap = float("inf")
        eta_pe = float("inf")
    return OrbitElements(
        apoapsis=apoapsis,
        periapsis=periapsis,
        eccentricity=ecc,
        inclination=incl,
        semimajoraxis=sma if math.isfinite(sma) else 0.0,
        eta_apoapsis=eta_ap,
        eta_periapsis=eta_pe,
        period=period,
    )


@dataclass
class FlightState:
    position: Vec3  # from body center
    velocity: Vec3
    facing: Vec3
    throttle: float = 0.0
    rcs: bool = False
    sas: bool = True
    abort: bool = False
    time: float = 0.0
    mission_start: float = 0.0


class PhysicsEngine:
    def __init__(self, body: Kerbin, vehicle: Vehicle) -> None:
        self.body = body
        self.vehicle = vehicle
        lat = math.radians(vehicle.latitude_deg)
        r = body.radius + vehicle.pad_altitude_m
        # Body-centered: x/z in meridian plane; +y east. Radial = local up.
        position = Vec3(
            r * math.cos(lat),
            0.0,
            r * math.sin(lat),
        )
        up = position.normalized()
        self.state = FlightState(
            position=position,
            velocity=Vec3(0.0, 0.0, 0.0),
            facing=up,
            throttle=0.0,
        )
        # Surface rotational velocity (eastward, +y)
        omega = 2.0 * math.pi / body.rotation_period
        east = Vec3(0.0, 1.0, 0.0)
        self.state.velocity = east * (omega * position.x)
        self._steering_target = up
        self._invariant_violations: list[str] = []

    @property
    def altitude(self) -> float:
        return self.state.position.mag() - self.body.radius

    def surface_rotation_velocity(self) -> Vec3:
        """Eastward velocity of the ground under the ship (inertial frame)."""
        east, _north, _up = local_basis(self.state.position)
        # Distance from rotation axis (Kerbin spins about +z)
        axis_r = math.hypot(self.state.position.x, self.state.position.y)
        omega = 2.0 * math.pi / self.body.rotation_period
        return east * (omega * axis_r)

    def surface_velocity(self) -> Vec3:
        return self.state.velocity - self.surface_rotation_velocity()

    def orbit(self) -> OrbitElements:
        return orbital_elements(self.state.position, self.state.velocity, self.body)

    def set_steering_target(self, direction: Vec3) -> None:
        if direction.mag() > 0:
            self._steering_target = direction.normalized()

    def advance(self, dt: float) -> None:
        if dt <= 0:
            return
        # Substep for stability
        sub = max(0.02, min(0.2, dt / max(1, int(dt / 0.1))))
        remaining = dt
        while remaining > 1e-9:
            step = min(sub, remaining)
            self._rk4_step(step)
            remaining -= step
            self._check_invariants()

    def _check_invariants(self) -> None:
        alt = self.altitude
        if alt < -1.0:
            self._invariant_violations.append(f"altitude={alt}")
        if not math.isfinite(self.state.position.x):
            self._invariant_violations.append("non-finite position")
        if self.state.throttle < -1e-6 or self.state.throttle > 1.0 + 1e-6:
            self._invariant_violations.append(f"throttle={self.state.throttle}")

    def consume_violations(self) -> list[str]:
        out = list(self._invariant_violations)
        self._invariant_violations.clear()
        return out

    def _accel(self, pos: Vec3, vel: Vec3, facing: Vec3, throttle: float) -> Vec3:
        r = pos.mag()
        if r <= 0:
            return Vec3(0.0, 0.0, 0.0)
        grav = pos.normalized() * (-self.body.mu / (r * r))
        alt = r - self.body.radius
        pressure = self.body.atm_pressure(alt)
        density = self.body.atm_density(alt)
        thrust_mag = self.vehicle.available_thrust(pressure) * max(0.0, min(1.0, throttle))
        thrust = facing.normalized() * thrust_mag
        # Drag opposite velocity
        speed = vel.mag()
        if density > 0 and speed > 0:
            drag_mag = 0.5 * density * speed * speed * self.vehicle.cd * self.vehicle.reference_area_m2
            drag = vel.normalized() * (-drag_mag)
        else:
            drag = Vec3(0.0, 0.0, 0.0)
        # Clamps: cancel horizontal and downward accel while held on pad
        mass = max(1.0, self.vehicle.total_mass())
        accel = (thrust + drag) / mass + grav
        if self.vehicle.clamps_held:
            # Hold to pad: zero acceleration relative to rotating frame approx
            up = pos.normalized()
            # Keep radial distance fixed and kill relative velocity buildup
            radial_speed = vel.dot(up)
            accel = accel - up * accel.dot(up)
            if radial_speed < 0:
                accel = accel - up * radial_speed  # damp
            # Soft lock position to pad radius
            pad_r = self.body.radius + self.vehicle.pad_altitude_m
            accel = accel + up * ((pad_r - r) * 5.0 - radial_speed * 2.0)
        return accel

    def _rk4_step(self, dt: float) -> None:
        # Attitude lag toward steering target
        max_rad = math.radians(self.vehicle.max_rate_deg_s) * dt
        facing = self.state.facing.normalized()
        target = self._steering_target.normalized()
        angle = math.radians(facing.angle_degrees(target))
        if angle > 1e-6:
            axis = facing.cross(target)
            if axis.mag() < 1e-9:
                # 180 deg flip — pick arbitrary axis
                axis = facing.cross(Vec3(0.0, 0.0, 1.0))
                if axis.mag() < 1e-9:
                    axis = Vec3(1.0, 0.0, 0.0)
            axis = axis.normalized()
            step = min(angle, max_rad)
            # Rodrigues rotation
            c = math.cos(step)
            s = math.sin(step)
            facing = (
                facing * c
                + axis.cross(facing) * s
                + axis * axis.dot(facing) * (1 - c)
            ).normalized()
            # Blend with lag gain
            blend = min(1.0, self.vehicle.lag_gain * dt)
            facing = (facing * (1 - blend) + target * blend).normalized()
        self.state.facing = facing

        throttle = self.state.throttle
        if self.vehicle.clamps_held:
            # engines may be lit but vehicle fixed
            pass

        pos = self.state.position
        vel = self.state.velocity

        def deriv(p: Vec3, v: Vec3) -> tuple[Vec3, Vec3]:
            a = self._accel(p, v, facing, throttle)
            return v, a

        k1p, k1v = deriv(pos, vel)
        k2p, k2v = deriv(pos + k1p * (dt / 2), vel + k1v * (dt / 2))
        k3p, k3v = deriv(pos + k2p * (dt / 2), vel + k2v * (dt / 2))
        k4p, k4v = deriv(pos + k3p * dt, vel + k3v * dt)

        new_pos = pos + (k1p + k2p * 2 + k3p * 2 + k4p) * (dt / 6)
        new_vel = vel + (k1v + k2v * 2 + k3v * 2 + k4v) * (dt / 6)

        # Fuel burn from average thrust
        pressure = self.body.atm_pressure(self.altitude)
        thrust = self.vehicle.available_thrust(pressure) * max(0.0, min(1.0, throttle))
        isp = self.vehicle.combined_isp(pressure)
        if not self.vehicle.clamps_held:
            self.vehicle.burn_fuel(thrust, isp, dt, G0)
        else:
            # Still burn while clamped if engines lit (countdown ignition)
            if thrust > 0:
                self.vehicle.burn_fuel(thrust, isp, dt, G0)

        self.state.position = new_pos
        self.state.velocity = new_vel
        self.state.time += dt

        # Surface impact — record fault; do not soft-stick and keep burning
        if self.altitude < 0 and not self.vehicle.clamps_held:
            self.state.position = self.state.position.normalized() * self.body.radius
            self.state.velocity = Vec3(0.0, 0.0, 0.0)
            self.state.throttle = 0.0
            self._invariant_violations.append(f"impact altitude={self.altitude}")
