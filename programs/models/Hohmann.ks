runOncePath("programs/models/OrbitChange"). // #include "./OrbitChange.ks"

function Hohmann {

    parameter target_altitude.

	local maneuvers is queue(
		OrbitChange(apoapsis, target_altitude),
		OrbitChange(target_altitude, target_altitude)
	).
	local active_maneuver is WaitUntil(time).
    local throttle_to is 0.

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
        return ship:prograde.
    }

    function getThrottle {
        return throttle_to.
    }

    function getName {
        return "Hohmann".
    }

	function _executeActiveManeuver {
		active_maneuver:update().
        set throttle_to to active_maneuver:getThrottle().
	}

    return lexicon(
        "isComplete", isComplete@,
        "update", update@,
        "getDirection", getDirection@,
        "getThrottle", getThrottle@,
        "getName", getName@
    ).
}
