function calculateEccentricity {
    parameter input_apoapsis is apoapsis.
    parameter input_periapsis is periapsis.
    local radius_at_apoapsis is input_apoapsis + ship:body:radius.
    local radius_at_periapsis is input_periapsis + ship:body:radius.
    return abs(1 - (2 / ((radius_at_apoapsis / radius_at_periapsis) + 1))).
}
