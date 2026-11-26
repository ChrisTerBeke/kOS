runOncePath("programs/models/OrbitChange"). // #include "./OrbitChange.ks"
runOncePath("programs/models/WaitUntil"). // #include "./WaitUntil.ks"

function Hohmann {

    parameter target_altitude.

    // Build burns lazily on first update so apo/peri reflect the parking orbit,
    // not the pad state when the mission config was constructed.
    local maneuvers is queue().
    local planned is false.
	local active_maneuver is WaitUntil(time).
    local throttle_to is 0.
    local steer_to is ship:prograde.

    function isComplete {
		return planned and active_maneuver:isComplete() and maneuvers:length = 0.
    }

    function update {
        if not planned {
            // Raise apoapsis to target, then circularize at the new apoapsis.
            maneuvers:push(OrbitChange(target_altitude, periapsis)).
            maneuvers:push(OrbitChange(target_altitude, target_altitude)).
            set planned to true.
        }
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
        return "Hohmann - " + active_maneuver:getName().
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
