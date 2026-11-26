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


def heading_direction(degrees_from_north: float, pitch_deg: float) -> Vec3:
    """Return unit vector: 0 deg = north (+y), 90 = east (+x), pitch 90 = up (+z)."""
    heading = math.radians(degrees_from_north)
    pitch = math.radians(pitch_deg)
    # Local ENU-ish: x east, y north, z up
    horizontal = math.cos(pitch)
    return Vec3(
        horizontal * math.sin(heading),
        horizontal * math.cos(heading),
        math.sin(pitch),
    ).normalized()
