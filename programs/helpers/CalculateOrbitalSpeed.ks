// calculate the required speed for circular orbit at the given altitude
function calculateOrbitalSpeed {
    parameter input_altitude is altitude.
    parameter input_apoapsis is apoapsis.
    parameter input_periapsis is periapsis.
    parameter semi_major_axis is ((ship:body:radius + input_apoapsis) + (ship:body:radius + input_periapsis)) / 2.
    return sqrt(ship:body:mu * ((2 / (ship:body:radius + input_altitude)) - (1 / (semi_major_axis)))).
}
