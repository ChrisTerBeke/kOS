runOncePath("programs/helpers/CalculateEccentricity").  // #include "../helpers/CalculateEccentricity.ks"

function OrbitalController {

    local is_enabled is false.

    // vehicle control variables
    local throttle_to is 0.
    local steer_to is ship:prograde.
    
    // orbital parameters
    local target_apoapsis is 0.
    local target_periapsis is 0.
    local max_apoapsis_deviation is 1000. // 1 km
    local max_periapsis_deviation is 1000. // 1 km
    local max_eccentricity_deviation is 0.01.

    // burn parameters
    local burn_started is false.
    local burn_delta_v is 0.
    local burn_time_remaining is 0.
    local burn_target_apoapsis is 0.
    local burn_target_periapsis is 0.
    local burn_altitude is 0.
    local burn_altitude_eta is 0.
    local burn_retrograde is false.

    function update {
        if not is_enabled {
            return.
        }
        _checkOrbit().
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
			"Pitch", getDirection():pitch,
            "Yaw", getDirection():yaw,
            "Roll", getDirection():roll,
			"Throttle", getThrottle(),
            "Burn time", burn_time_remaining,
            "Delta V", burn_delta_v
		).
	}

    // (re)configure the orbit profile
    function setOrbitProfile {
        parameter orbit_parameters.
        set target_apoapsis to orbit_parameters["target_apoapsis"].
        set target_periapsis to orbit_parameters["target_periapsis"].
    }

    function _checkOrbit {
        // TODO: prevent long burns (30s+) that cause high eccentricity and use multiple burns instead
        // TODO: add inclination change logic (e.g. burn vector instead of prograde/retrograde)

        // calculate next burn if not already burning
        if not burn_started {
            local should_adjust_periapsis is abs(periapsis - target_periapsis) > max_periapsis_deviation.
            if eta:apoapsis < eta:periapsis and should_adjust_periapsis {
                set burn_target_apoapsis to apoapsis.
                set burn_target_periapsis to target_periapsis.
                set burn_altitude to apoapsis.
                set burn_altitude_eta to eta:apoapsis.
                set burn_retrograde to periapsis > burn_target_periapsis.
            }
            local should_adjust_apoapsis is abs(apoapsis - target_apoapsis) > max_apoapsis_deviation.
            if eta:periapsis < eta:apoapsis and should_adjust_apoapsis {
                set burn_target_apoapsis to target_apoapsis.
                set burn_target_periapsis to periapsis.
                set burn_altitude to periapsis.
                set burn_altitude_eta to eta:periapsis.
                set burn_retrograde to apoapsis > burn_target_apoapsis.
            }
        }

        // check if we need to burn prograde or retrograde
        if burn_retrograde {
            set steer_to to ship:retrograde.
        } else {
            set steer_to to ship:prograde.
        }

        // calculate the required burn time
        // TODO: correctly calculate burn_time_remaining when delta_v is negative (retrograde burn)
        set burn_delta_v to calculateDeltaV(burn_altitude, burn_target_apoapsis, burn_target_periapsis).
        set burn_time_remaining to calculateRemainingBurnTime(burn_delta_v).

        // full throttle 50% before and 50% after apoapsis/periapsis
        if burn_altitude_eta <= (burn_time_remaining / 2) and not burn_started {
            set throttle_to to 1.
            set burn_started to true.
        }

        // reduce throttle towards end of burn to improve accuracy
        if burn_started {
            local target_eccentricity is calculateEccentricity(burn_target_apoapsis, burn_target_periapsis).
            if abs(ship:orbit:eccentricity - target_eccentricity) < max_eccentricity_deviation {
                set throttle_to to 0.1.
            }
        }

        // cut engines at end of burn
        if burn_started and burn_time_remaining <= 0 {
            set throttle_to to 0.
            set burn_started to false.
        }
    }

    return lexicon(
        "update", update@,
        "setEnabled", setEnabled@,
        "doAbort", doAbort@,
		"getDirection", getDirection@,
		"getThrottle", getThrottle@,
		"getTelemetry", getTelemetry@,
        "setOrbitProfile", setOrbitProfile@
    ).
}
