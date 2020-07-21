runOncePath("programs/helpers/CalculateOrbitalSpeed").  // #include "./CalculateOrbitalSpeed.ks"

// calculate the required DeltaV to achieve an orbit when burning at the given altitude
function calculateDeltaV {
    parameter input_altitude.
    parameter target_orbit_apoapsis is input_altitude.
    parameter target_orbit_periapsis is input_altitude.
    local current_velocity is calculateOrbitalSpeed(input_altitude).
    local target_velocity is calculateOrbitalSpeed(input_altitude, target_orbit_apoapsis, target_orbit_periapsis).
    return target_velocity - current_velocity.
}
