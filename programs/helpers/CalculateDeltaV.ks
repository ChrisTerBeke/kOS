runOncePath("programs/helpers/CalculateOrbitalSpeed").  // #include "./CalculateOrbitalSpeed.ks"

// calculate the required DeltaV to achieve an orbit when burning at the given altitude
function calculateDeltaV {
    parameter burn_altitude.
    parameter target_orbit_apoapsis is burn_altitude.
    parameter target_orbit_periapsis is burn_altitude.
    local current_velocity is calculateOrbitalSpeed(burn_altitude, apoapsis, periapsis).
    local target_velocity is calculateOrbitalSpeed(burn_altitude, target_orbit_apoapsis, target_orbit_periapsis).
    return target_velocity - current_velocity.
}
