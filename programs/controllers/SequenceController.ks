runOncePath("programs/helpers/CalculateUpDirection").  // #include "../helpers/CalculateUpDirection.ks"
runOncePath("programs/models/Hohmann").  // #include "../models/Hohmann.ks"
runOncePath("programs/models/Launch").  // #include "../models/Launch.ks"
runOncePath("programs/models/WaitUntil").  // #include "../models/WaitUntil.ks"

function SequenceController {

    local is_enabled is false.

    // TODO: load parameters from config file
    local launch_altitude is 120000.
    local launch_inclination is 0.
    local launch_roll is 0.
    local final_altitude is 140000.

    // TODO: load maneuvers from config file
    local maneuvers is queue(
        Launch(launch_altitude, launch_inclination, launch_roll),
        Hohmann(final_altitude)
    ).
    local active_maneuver is WaitUntil(time).
    local throttle_to is 0.
    local steer_to is calculateUpDirection().

    function setEnabled {
        parameter value.
        if is_enabled = value {
            return.
        }
        set is_enabled to value.
    }

    function update {
        if not is_enabled {
            return.
        }
        if active_maneuver:isComplete() and maneuvers:length > 0 {
            set active_maneuver to maneuvers:pop().
        }
        _executeActiveManeuver().
    }

    function isComplete {
        return active_maneuver:isComplete() and maneuvers:length = 0.
    }

    function doAbort {
        // TODO: implement this
        return false.
    }

    function getDirection {
        return steer_to.
    }

    function getThrottle {
        return throttle_to.
    }

    function getTelemetry {
        return lexicon(
            "Time", time:seconds,
            "Altitude", ship:altitude,
            "Ground speed", ship:groundspeed,
            "Vertical speed", ship:verticalspeed,
            "Delta V", ship:deltav:vacuum,
            "Apoapsis", ship:orbit:apoapsis,
            "ETA apoapsis", eta:apoapsis,
            "Periapsis", ship:orbit:periapsis,
            "ETA periapsis", eta:periapsis,
            "Eccentricity", ship:orbit:eccentricity,
            "Inclination", ship:orbit:inclination,
			"Pitch", steer_to:pitch,
            "Yaw", steer_to:yaw,
            "Roll", steer_to:roll,
			"Throttle", throttle_to
		).
    }

    function getMessages {
        // TODO: implement this
        return list().
    }

    function _executeActiveManeuver {
        active_maneuver:update().
        set throttle_to to active_maneuver:getThrottle().
        set steer_to to active_maneuver:getDirection().
    }

    return lexicon(
        "setEnabled", setEnabled@,
        "update", update@,
        "isComplete", isComplete@,
        "doAbort", doAbort@,
        "getDirection", getDirection@,
        "getThrottle", getThrottle@,
        "getTelemetry", getTelemetry@,
        "getMessages", getMessages@
    ).
}
