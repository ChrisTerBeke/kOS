// check if at least one engine on our current stage is out of fuel
function checkEngineFlameOut {
    list engines in engine_list.
    local has_flameout is false.
    for engine in engine_list {
        if engine:ignition and engine:flameout {
            set has_flameout to true.
            break.
        }
    }
    return has_flameout.
}
