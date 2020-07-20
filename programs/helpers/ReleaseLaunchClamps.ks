// release all launch clamps
function releaseLaunchClamps {
    for clamp in ship:modulesNamed("LaunchClamp") {
        if clamp:hasEvent("release clamp") {
            clamp:doEvent("release clamp").
        }
    }
}
