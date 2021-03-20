runOncePath("programs/helpers/CalculateUpDirection").  // #include "../helpers/CalculateUpDirection.ks"
runOncePath("programs/helpers/ReleaseLaunchClamps").  // #include "../helpers/ReleaseLaunchClamps.ks"

function CountDown {

    parameter countdown_from.

    local launch_time is 0.
    local lift_off is false.
    local throttle_to is 0.
    local steer_to is calculateUpDirection().

    function isComplete {
        return lift_off.
    }

    function update {

        // calculate launch time once
        if launch_time = 0 {
            set launch_time to time:seconds + countdown_from.
        }

        local time_to_launch is launch_time - time:seconds.

        if time_to_launch <= 3 and throttle_to < 1 {
            set throttle_to to 1.
            stage. // start engines
        }

        if time_to_launch <= 0 {
            releaseLaunchClamps().
            set lift_off to true.
        }
    }

    function getDirection {
        return steer_to.
    }

    function getThrottle {
        return throttle_to.
    }

    return lexicon(
        "isComplete", isComplete@,
        "update", update@,
        "getDirection", getDirection@,
        "getThrottle", getThrottle@
    ).
}
