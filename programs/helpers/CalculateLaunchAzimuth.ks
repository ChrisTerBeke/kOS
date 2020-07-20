runOncePath("programs/helpers/CalculateOrbitalSpeed").  // #include "./CalculateOrbitalSpeed.ks"

// calculate the launch azimuth for a given altitude, inclination and launch location
function calculateLaunchAzimuth {
    parameter target_altitude.
    parameter target_inclination.
    parameter launch_location.
    local target_apoapsis_and_periapsis is ship:body:radius + target_altitude.
    local target_orbital_speed is calculateOrbitalSpeed(target_altitude, target_apoapsis_and_periapsis, target_apoapsis_and_periapsis).
    local inertial_azimuth is arcSin(max(min(cos(target_inclination) / cos(launch_location:lat), 1), -1)).
    local rotational_velocity_x is target_orbital_speed * sin(inertial_azimuth) - (6.2832 * ship:body:radius / ship:body:rotationperiod).
    local rotational_velocity_y is target_orbital_speed * cos(inertial_azimuth).
    return arcTan(rotational_velocity_x / rotational_velocity_y).
}
