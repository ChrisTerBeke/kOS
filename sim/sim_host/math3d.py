from __future__ import annotations

import math
from dataclasses import dataclass


@dataclass(frozen=True)
class Vec3:
    x: float
    y: float
    z: float

    def __add__(self, other: Vec3) -> Vec3:
        return Vec3(self.x + other.x, self.y + other.y, self.z + other.z)

    def __sub__(self, other: Vec3) -> Vec3:
        return Vec3(self.x - other.x, self.y - other.y, self.z - other.z)

    def __mul__(self, scalar: float) -> Vec3:
        return Vec3(self.x * scalar, self.y * scalar, self.z * scalar)

    __rmul__ = __mul__

    def __truediv__(self, scalar: float) -> Vec3:
        return Vec3(self.x / scalar, self.y / scalar, self.z / scalar)

    def dot(self, other: Vec3) -> float:
        return self.x * other.x + self.y * other.y + self.z * other.z

    def cross(self, other: Vec3) -> Vec3:
        return Vec3(
            self.y * other.z - self.z * other.y,
            self.z * other.x - self.x * other.z,
            self.x * other.y - self.y * other.x,
        )

    def mag(self) -> float:
        return math.sqrt(self.dot(self))

    def normalized(self) -> Vec3:
        m = self.mag()
        if m <= 0:
            return Vec3(0.0, 0.0, 0.0)
        return self / m

    def angle_degrees(self, other: Vec3) -> float:
        a = self.normalized()
        b = other.normalized()
        c = max(-1.0, min(1.0, a.dot(b)))
        return math.degrees(math.acos(c))


def local_basis(position: Vec3) -> tuple[Vec3, Vec3, Vec3]:
    """Return (east, north, up) orthonormal basis at body-centered position."""
    up = position.normalized()
    world_north = Vec3(0.0, 0.0, 1.0)
    east = world_north.cross(up)
    if east.mag() < 1e-9:
        # Near pole — pick an arbitrary east
        east = Vec3(0.0, 1.0, 0.0).cross(up)
    east = east.normalized()
    north = up.cross(east).normalized()
    return east, north, up


def heading_direction(
    degrees_from_north: float,
    pitch_deg: float,
    position: Vec3 | None = None,
) -> Vec3:
    """Unit look vector: 0°=north, 90°=east, pitch 90°=up.

    If ``position`` is given, express the result in the body-centered frame
    using the local ENU basis at that point. Otherwise use absolute ENU
    (z-up) for unit tests.
    """
    heading = math.radians(degrees_from_north)
    pitch = math.radians(pitch_deg)
    horizontal = math.cos(pitch)
    local = Vec3(
        horizontal * math.sin(heading),  # east component
        horizontal * math.cos(heading),  # north component
        math.sin(pitch),  # up component
    )
    if position is None:
        return local.normalized()
    east, north, up = local_basis(position)
    return (east * local.x + north * local.y + up * local.z).normalized()
