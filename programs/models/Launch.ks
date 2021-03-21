runOncePath("programs/helpers/CalculateLaunchAzimuth").  // #include "../helpers/CalculateLaunchAzimuth.ks"
runOncePath("programs/helpers/CalculateUpDirection").  // #include "../helpers/CalculateUpDirection.ks"
runOncePath("programs/models/Circularize").  // #include "./Circularize.ks"
runOncePath("programs/models/CountDown").  // #include "./CountDown.ks"
runOncePath("programs/models/GravityTurn").  // #include "./GravityTurn.ks"
runOncePath("programs/models/VerticalAscent").  // #include "./VerticalAscent.ks"
runOncePath("programs/models/WaitUntil").  // #include "./WaitUntil.ks"

function Launch {

    // launch parameters
    parameter target_altitude.
    parameter target_inclination.
    parameter roll.

    // launch constants
    local roll_start_altitude is 200.
    local gravity_turn_start_altitude is 1500.
    local launch_countdown_seconds is 10.
    local launch_location is ship:geoPosition.
    local launch_azimuth is calculateLaunchAzimuth(target_altitude, target_inclination, launch_location).

    // a launch consists of several maneuvers executed in sequence
    local maneuvers is queue(
        CountDown(launch_countdown_seconds),
        VerticalAscent(roll, roll_start_altitude, gravity_turn_start_altitude),
        GravityTurn(roll, gravity_turn_start_altitude, target_altitude, target_inclination, launch_azimuth),
        Circularize(target_altitude)
    ).
    local active_maneuver is WaitUntil(time).
    local throttle_to is 0.
    local steer_to is calculateUpDirection().

    function isComplete {
        return active_maneuver:isComplete() and maneuvers:length = 0.
    }

    function update {
        if active_maneuver:isComplete() and maneuvers:length > 0 {
            set active_maneuver to maneuvers:pop().
        }
        _executeActiveManeuver().
    }

    function getDirection {
        return steer_to.
    }

    function getThrottle {
        return throttle_to.
    }

    function getName {
        return "Launch - " + active_maneuver:getName().
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
