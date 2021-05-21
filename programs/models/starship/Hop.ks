runOncePath("programs/models/CountDown").  // #include "../CountDown.ks"
runOncePath("programs/models/WaitUntil").  // #include "../WaitUntil.ks"
runOncePath("programs/models/starship/Ascent").  // #include "./Ascent.ks"
runOncePath("programs/models/starship/Flop").  // #include "./Flop.ks"

function Hop {

    // launch parameters
    parameter target_altitude.

    // launch constants
    local launch_countdown_seconds is 3.

    // a hop consists of several maneuvers executed in sequence
    local maneuvers is queue(
        CountDown(launch_countdown_seconds),
        Ascent(target_altitude),
        Flop()
    ).
    local active_maneuver is WaitUntil(time).
    local throttle_to is 0.
    local steer_to is calculateUpDirection().

    function isComplete {
        return active_maneuver:isComplete() and maneuvers:length = 0.
    }

    function update {
        _executeActiveManeuver().
        if active_maneuver:isComplete() and maneuvers:length > 0 {
            set active_maneuver to maneuvers:pop().
        }
    }

    function getDirection {
        return steer_to.
    }

    function getThrottle {
        return throttle_to.
    }

    function getName {
        return "Hop - " + active_maneuver:getName().
    }

    function _executeActiveManeuver {
        active_maneuver:update().
        set throttle_to to active_maneuver:getThrottle().
        set steer_to to active_maneuver:getDirection().
    }

    return lexicon(
        "isComplete", isComplete@,
        "update", update@,
        "getDirection", getDirection@,
        "getThrottle", getThrottle@,
        "getName", getName@
    ).
}
