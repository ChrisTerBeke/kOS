from __future__ import annotations

import math


class Kerbin:
    """Kerbin physical constants (KSP stock)."""

    name = "Kerbin"
    mu = 3.5316000e12
    radius = 600_000.0
    rotation_period = 21_649.426
    atm_height = 70_000.0
    # Approximate sea-level density / scale height for an exponential model
    atm_asl_density = 1.225
    atm_scale_height = 5600.0
    atm_asl_pressure = 101325.0

    def atm_pressure(self, altitude: float) -> float:
        if altitude >= self.atm_height or altitude < 0:
            return 0.0
        return self.atm_asl_pressure * math.exp(-altitude / self.atm_scale_height)

    def atm_density(self, altitude: float) -> float:
        if altitude >= self.atm_height or altitude < 0:
            return 0.0
        return self.atm_asl_density * math.exp(-altitude / self.atm_scale_height)
