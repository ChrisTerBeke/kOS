function getThrustForStage {
    list engines in engine_list.
    local available_thrust is 0.
    for engine in engine_list {
        if engine:ignition and not engine:flameout {
            set available_thrust to available_thrust + engine:availablethrust.
        }
    }
    return available_thrust.
}
