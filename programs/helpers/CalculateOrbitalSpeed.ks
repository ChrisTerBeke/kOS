// calculate the required speed for circular orbit at the given altitude
function calculateOrbitalSpeed {
    parameter target_altitude.
    return sqrt(ship:body:mu * ((2 / (ship:body:radius + target_altitude)) - (1 / (ship:body:radius + target_altitude)))).
}
