// calculate the remaining time in seconds to reach the desired circular orbit
function calculateRemainingBurnTime {
    parameter target_orbital_speed.
    return abs(target_orbital_speed - ship:velocity:orbit:mag) / max((ship:availablethrust / ship:mass), 0.001).
}
