// release all launch clamps
function releaseLaunchClamps {
    for clamp in ship:modulesNamed("LaunchClamp") {
        clamp:doEvent("release clamp").
    }
}
