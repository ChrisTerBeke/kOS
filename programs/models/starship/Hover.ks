runOncePath("programs/helpers/CalculateUpDirection").  // #include "../../helpers/CalculateUpDirection.ks"
runOncePath("programs/helpers/GetThrustForStage").  // #include "../../helpers/GetThrustForStage.ks"

function Hover {

    // TODO: descent back to pad after x seconds of hovering
    // TODO: cancel horizontal speed to land back on pad

    parameter target_altitude.

    local throttle_to is 1.

    local vertical_speed_pid is pidLoop(3, 0.3, 1).
    local vertical_acceleration_pid is pidLoop(3, 0.1, 0.1).

    function isComplete {
        return false.
    }

    function update {
        local height_above_ground is ship:altitude - ship:geoposition:terrainHeight.
        local g_force is ship:body:mu / (ship:body:radius + ship:altitude) ^ 2.

        // bounds
        local maximum_vertical_acceleration is getThrustForStage() / ship:mass.
        local minimum_vertical_speed is min(0, 0 - sqrt(abs(target_altitude - height_above_ground) * 2 * (maximum_vertical_acceleration - g_force))).
        local maximum_vertical_speed is max(0, sqrt(abs(target_altitude - height_above_ground) * 2 * g_force)).

        // velocity control
        set vertical_speed_pid:setPoint to target_altitude.
        set vertical_speed_pid:minOutput to minimum_vertical_speed.
        set vertical_speed_pid:maxOutput to maximum_vertical_speed.
        local target_vertical_speed is vertical_speed_pid:update(time:seconds, height_above_ground).

        // acceleration control
        set vertical_acceleration_pid:setPoint to target_vertical_speed.
        local target_vertical_acceleration is vertical_acceleration_pid:update(time:seconds, ship:verticalspeed).

        // throttle control
        set throttle_to to max(0, min(1, target_vertical_acceleration / maximum_vertical_acceleration)).
    }

    function getDirection {
        return calculateUpDirection().
    }

    function getThrottle {
        return throttle_to.
    }

    function getName {
        return "Hover (" + throttle_to + ")".
    }

    return lexicon(
        "isComplete", isComplete@,
        "update", update@,
        "getDirection", getDirection@,
        "getThrottle", getThrottle@,
        "getName", getName@
    ).
}
