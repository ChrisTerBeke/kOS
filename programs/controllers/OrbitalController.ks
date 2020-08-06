runOncePath("programs/models/Hohmann"). // #include "../models/Hohmann.ks"
runOncePath("programs/models/WaitUntil"). // #include "../models/WaitUntil.ks"

function OrbitalController {

    local is_enabled is false.
    local message_list is list().

    // maneuvers
    local maneuvers is queue().
    local current_maneuver is WaitUntil(time).

    // vehicle control variables
    local throttle_to is 0.
    local steer_to is ship:prograde.

    function update {
        if not is_enabled {
            return.
        }
        // go to the next planned maneuver in the queue if the current one is done
        if current_maneuver:isComplete() and maneuvers:length > 0 {
            set current_maneuver to maneuvers:pop().
            _logWithT("Executing next planned maneuver.").
        }
        _executeCurrentManeuver().
    }

    function setEnabled {
        parameter value.
		if is_enabled = value {
			return.
		}
        set is_enabled to value.
    }

    function doAbort {
        set is_enabled to false.
    }

	function getDirection {
		return steer_to.
	}

	function getThrottle {
		return throttle_to.
	}

	function getTelemetry {
		return lexicon(
			"Pitch", steer_to:pitch,
            "Yaw", steer_to:yaw,
            "Roll", steer_to:roll,
			"Throttle", throttle_to,
            "Burn time", _getBurnTimeForCurrentManeuver()
		).
	}

    function getMessages {
        local messages is message_list:copy().
        message_list:clear().
        return messages.
    }

    function setManeuvers {
        parameter input_maneuvers.
        maneuvers:clear().
        for input_maneuver in input_maneuvers {
            if input_maneuver["maneuver_type"] = "hohmann" {
                // TODO: some more checking
                local maneuver is Hohmann(input_maneuver["target_altitude"]).
                maneuvers:push(maneuver).
            }
        }
    }

    function isComplete {
        return current_maneuver:isComplete() and maneuvers:length = 0.
    }

    function _executeCurrentManeuver {
        current_maneuver:update().
        set steer_to to current_maneuver:getDirection().
        set throttle_to to current_maneuver:getThrottle().
    }

    function _getBurnTimeForCurrentManeuver {
        return current_maneuver:nextBurnRemainingTime().
    }

    function _logWithT {
        local parameter text.
        local line is "T+" + round(missionTime, 2) + ": " + text.
        message_list:add(line).
    }

    return lexicon(
        "update", update@,
        "setEnabled", setEnabled@,
        "doAbort", doAbort@,
		"getDirection", getDirection@,
		"getThrottle", getThrottle@,
		"getTelemetry", getTelemetry@,
        "getMessages", getMessages@,
        "isComplete", isComplete@,
        "setManeuvers", setManeuvers@
    ).
}
