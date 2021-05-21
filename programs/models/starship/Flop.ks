runOncePath("programs/helpers/CalculateUpDirection").  // #include "../../helpers/CalculateUpDirection.ks"
runOncePath("programs/helpers/GetThrustForStage").  // #include "../../helpers/GetThrustForStage.ks"

function Flop {

    local throttle_to is 0.1.
    local steer_to is up + r(-45, 0, 180). // north

    // TODO: make helper function for accessing flaps
    local flaps is ship:modulesNamed("ModuleRoboticServoHinge").
    local bottom_left_flap is flaps[1].
    local bottom_right_flap is flaps[0].
    local top_left_flap is flaps[2].
    local top_right_flap is flaps[3].

    function isComplete {
        return ship:facing:pitch < 320 and ship:facing:pitch > 180.
    }

    function update {
        // TODO: don't execute every cycle
        bottom_left_flap:setField("Target Angle", 90).
        bottom_right_flap:setField("Target Angle", 90).
        top_left_flap:setField("Target Angle", 0).
        top_right_flap:setField("Target Angle", 0).
    }

    function getDirection {
        return steer_to.
    }

    function getThrottle {
        return throttle_to.
    }

    function getName {
        return "Flop".
    }

    return lexicon(
        "isComplete", isComplete@,
        "update", update@,
        "getDirection", getDirection@,
        "getThrottle", getThrottle@,
        "getName", getName@
    ).
}
