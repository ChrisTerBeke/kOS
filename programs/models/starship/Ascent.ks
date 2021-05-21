runOncePath("programs/helpers/CalculateUpDirection").  // #include "../../helpers/CalculateUpDirection.ks"
runOncePath("programs/helpers/GetThrustForStage").  // #include "../../helpers/GetThrustForStage.ks"

function Ascent {

    parameter target_altitude.

    local throttle_to is 0.
    local steer_to is calculateUpDirection().

    // TODO: not hardcode these
    local landing_pad_latitude is -0.09721.
    local landing_pad_longitude is -74.55766.

    // TODO: tune pids to prevent overshoot
    local vertical_speed_pid is pidLoop(1, 0.1, 1).
    local vertical_acceleration_pid is pidLoop(1, 0.1, 0.1).

    function isComplete {
        return ship:altitude > target_altitude.
    }

    function update {

        // keep pointing to a line straight above the landing pad
        local latitude_from_pad is landing_pad_latitude - ship:geoPosition:lat.
        local longitude_from_pad is landing_pad_longitude - ship:geoposition:lng.
        set steer_to to up + r((-latitude_from_pad * 100) + 2, -longitude_from_pad * 500, 180).

        // bounds
        local height_above_ground is ship:altitude - ship:geoposition:terrainHeight.
        local g_force is ship:body:mu / (ship:body:radius + ship:altitude) ^ 2.
        local maximum_vertical_acceleration is getThrustForStage() / ship:mass.
        local minimum_vertical_speed is min(0, 0 - sqrt(abs(target_altitude - height_above_ground) * 2 * (maximum_vertical_acceleration - g_force))).
        local maximum_vertical_speed is min(35, sqrt(abs(target_altitude - height_above_ground) * 2 * g_force)).

        // velocity control
        set vertical_speed_pid:setPoint to target_altitude.
        set vertical_speed_pid:minOutput to minimum_vertical_speed.
        set vertical_speed_pid:maxOutput to maximum_vertical_speed.
        local target_vertical_speed is vertical_speed_pid:update(time:seconds, height_above_ground).

        // acceleration control
        set vertical_acceleration_pid:setPoint to target_vertical_speed.
        local target_vertical_acceleration is vertical_acceleration_pid:update(time:seconds, ship:verticalspeed).

        // throttle control
        set throttle_to to max(0.1, min(1, target_vertical_acceleration / maximum_vertical_acceleration)).
    }

    function getDirection {
        return steer_to.
    }

    function getThrottle {
        return throttle_to.
    }

    function getName {
        return "Ascent (" + throttle_to + ")".
    }

    return lexicon(
        "isComplete", isComplete@,
        "update", update@,
        "getDirection", getDirection@,
        "getThrottle", getThrottle@,
        "getName", getName@
    ).
}
