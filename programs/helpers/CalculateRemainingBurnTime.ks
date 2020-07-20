runOncePath("programs/helpers/CalculateSpecificImpulse").  // #include "./CalculateSpecificImpulse.ks"

// calculate the remaining time in seconds to reach the desired circular orbit
function calculateRemainingBurnTime {
    parameter delta_v.
    local specific_impulse is calculateSpecificImpulse().
    if specific_impulse = 0 { return 0. }
    local exhaust_velocity is specific_impulse * constant:g0.
    return ((ship:mass * exhaust_velocity) / ship:availableThrust) * (1 - (constant:e ^ ((delta_v / exhaust_velocity) * -1))).
}
