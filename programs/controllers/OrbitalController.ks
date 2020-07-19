function OrbitalController {

    // this is the initial altitude when the controller kicks in
    // we can change the target altitude later while in orbit mode
    parameter target_altitude.
    parameter target_inclination is 0.

    local is_enabled is false.

    function update {
        if not is_enabled {
            return.
        }
        // TODO: be in either altitude or incliation adjustment mode
        _checkAltitude().
        _checkInclination().
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

    function setTargetAltitude {
        parameter value.
        set target_altitude to value.
    }

    function setTargetInclination {
        parameter value.
        set target_inclination to value.
    }

	function getDirection {
		// TODO
		return ship:prograde.
	}

	function getThrottle {
		// TODO
		return 0.
	}

    function _checkAltitude {
		// TODO
        // 1) check if current altitude is close to target altitude (with low eccentricity)
        // 2) calculate DeltaV for burn at apoapsis to raise or lower periapsis
        // 3) execute burn to ajust periapsis to target altitude (periapsis might become apoapsis!)
        // 4) repeat until condition in step 1 is met
    }

    function _checkInclination {
        // TODO
    }

    return lexicon(
        "update", update@,
        "setEnabled", setEnabled@,
        "doAbort", doAbort@,
        "setTargetAltitude", setTargetAltitude@,
        "setTargetInclination", setTargetInclination@,
		"getDirection", getDirection@,
		"getThrottle", getThrottle@
    ).
}
