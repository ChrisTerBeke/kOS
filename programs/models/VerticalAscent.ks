runOncePath("programs/helpers/CalculateHeading").  // #include "../helpers/CalculateHeading.ks"
runOncePath("programs/helpers/CalculateUpDirection").  // #include "../helpers/CalculateUpDirection.ks"

function VerticalAscent {

    parameter roll.
    parameter roll_start_altitude.
    parameter gravity_turn_start_altitude.
    parameter target_inclination.
    parameter launch_azimuth.

    local start_gravity_turn is false.
    local throttle_to is 1.
    local steer_to is calculateUpDirection().

    function isComplete {
        return start_gravity_turn.
    }

    function update {
        if altitude > roll_start_altitude {
            local steer_to_direction is calculateDirection(target_inclination, launch_azimuth).
            set steer_to to calculateHeading(steer_to_direction, 90, roll).
        }
        if altitude > gravity_turn_start_altitude {
            set start_gravity_turn to true.
        }
    }

    function getDirection {
        return steer_to.
    }

    function getThrottle {
        return throttle_to.
    }

    function getName {
        return "Vertical ascent".
    }

    return lexicon(
        "isComplete", isComplete@,
        "update", update@,
        "getDirection", getDirection@,
        "getThrottle", getThrottle@,
        "getName", getName@
    ).
}
