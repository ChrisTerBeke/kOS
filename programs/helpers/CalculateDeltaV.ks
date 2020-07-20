runOncePath("programs/helpers/CalculateOrbitalSpeed").  // #include "./CalculateOrbitalSpeed.ks"

// calculate the required DeltaV to achieve a circular orbit at the give input altitude
function calculateDeltaV {
    parameter input_altitude.
    local current_velocity is calculateOrbitalSpeed().
    local target_velocity is calculateOrbitalSpeed(input_altitude, input_altitude, input_altitude).
    return target_velocity - current_velocity.
}
