// calculate the specific impulse for all active engines combined
function calculateSpecificImpulse {
    local specific_impulse is 0.
    list engines in engine_list.
    for engine in engine_list {
        if engine:ignition and not engine:flameout {
            set specific_impulse to specific_impulse + (engine:isp * (engine:availableThrust / ship:availableThrust)).
        }
    }
    return specific_impulse.
}
