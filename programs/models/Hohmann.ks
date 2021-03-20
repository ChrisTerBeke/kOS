runOncePath("programs/models/Orbit"). // #include "./Orbit.ks"
runOncePath("programs/models/OrbitChange"). // #include "./OrbitChange.ks"

function Hohmann {

    parameter target_altitude.
	// TODO: allow non-circular orbits
    // TODO: allow inclination change

	// a Hohmann transfer is essentially 2 orbit change burns
	local maneuvers is queue(
		OrbitChange(apoapsis, target_altitude),
		OrbitChange(target_altitude, target_altitude)
	).
	local active_maneuver is WaitUntil(time).
    local throttle_to is 0.

    function isComplete {
		return active_maneuver:isComplete() and maneuvers:length = 0.
    }

	function nextBurnRemainingTime {
		return active_maneuver:nextBurnRemainingTime().
	}

    function update {
		// go to the next planned maneuver in the queue if the current one is done
        if active_maneuver:isComplete() and maneuvers:length > 0 {
            set active_maneuver to maneuvers:pop().
        }
        _executeActiveManeuver().
    }

    function getDirection {
        return ship:prograde.
    }

    function getThrottle {
        return throttle_to.
    }

	function _executeActiveManeuver {
		active_maneuver:update().
        set throttle_to to active_maneuver:getThrottle().
	}

    return lexicon(
        "nextBurnRemainingTime", nextBurnRemainingTime@,
        "isComplete", isComplete@,
        "update", update@,
        "getDirection", getDirection@,
        "getThrottle", getThrottle@
    ).
}
