runOncePath("programs/helpers/CalculateDeltaV"). // #include "../helpers/CalculateDeltaV.ks"
runOncePath("programs/models/Orbit"). // #include "../models/Orbit.ks"

global ORBIT_MODE_IDLE is -1.
global ORBIT_MODE_ORIGINAL is 0.
global ORBIT_MODE_TRANSFER is 1.
global ORBIT_MODE_FINAL is 2.

function OrbitalController {

    local is_enabled is false.
    local message_list is list().

    // vehicle control variables
    local throttle_to is 0.
    local steer_to is ship:prograde.
    
    // orbital parameters
    local orbit_mode is ORBIT_MODE_IDLE.
    local original_orbit is false.
    local target_apoapsis is 0.
    local target_periapsis is 0.

    // burn parameters
    local burn_started is false.
    local burn_delta_v is 0.
    local burn_time_remaining is 0.

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

    function getMessages {
        local messages is message_list:copy().
        message_list:clear().
        return messages.
    }

    // (re)configure the orbit profile
    function setOrbitProfile {
        parameter orbit_parameters.
        set target_apoapsis to orbit_parameters["target_apoapsis"].
        set target_periapsis to orbit_parameters["target_periapsis"].
        // TODO: add target inclination
    }

    function _checkOrbit {
        // TODO: add inclination change logic (e.g. burn vector instead of prograde)
        // TODO: prevent long burns (30s+) that cause high eccentricity deviation and use multiple burns instead
        // TODO: improve accuracy for larger orbital insertion burns (e.g. to geostationary transfer orbit)

        // TODO: only trigger this on input?
        if orbit_mode = ORBIT_MODE_IDLE {
            set original_orbit to Orbit(apoapsis, periapsis, ship:orbit:inclination).
            set orbit_mode to ORBIT_MODE_ORIGINAL.
        }

        // define the three orbits involved in a Hohmann-like transfer
        local current_orbit is Orbit(apoapsis, periapsis, ship:orbit:inclination).
        local transfer_orbit is Orbit(target_apoapsis, original_orbit:getApoapsis(), ship:orbit:inclination).
        local final_orbit is Orbit(target_apoapsis, target_periapsis, ship:orbit:inclination).
        local target_orbit is current_orbit.

        // calculate DeltaV needed to get from the original orbit into the transer orbit
        if orbit_mode = ORBIT_MODE_ORIGINAL {
            set burn_delta_v to calculateDeltaV(current_orbit:getApoapsis(), transfer_orbit:getApoapsis(), transfer_orbit:getPeriapsis()).
            set target_orbit to transfer_orbit.
        }

        // calculate DeltaV needed to get from the transfer orbit into the final orbit
        if orbit_mode = ORBIT_MODE_TRANSFER {
            set burn_delta_v to calculateDeltaV(transfer_orbit:getApoapsis(), final_orbit:getApoapsis(), final_orbit:getPeriapsis()).
            set target_orbit to final_orbit.
        }

        set burn_time_remaining to calculateRemainingBurnTime(burn_delta_v).
        set steer_to to ship:prograde.

        // start burning at 50% of our total burn time before apoapsis for highest precision
        if eta:apoapsis <= (burn_time_remaining / 2) and not burn_started {
            set throttle_to to 1.
            set burn_started to true.
            _logWithT("Started orbital correction burn.").
        }

        // reduce throttle towards end of burn to improve accuracy
        if burn_started and abs(current_orbit:getEccentricity() - target_orbit:getEccentricity()) < 0.01 {
            set throttle_to to 0.1.
        }

        // cut engines at end of burn and update orbit mode
        if burn_started and burn_time_remaining < 0.05 {
            set throttle_to to 0.
            set burn_started to false.
            // TODO: check if our orbit is actually correct
            if orbit_mode = ORBIT_MODE_ORIGINAL {
                set orbit_mode to ORBIT_MODE_TRANSFER.
            } else if orbit_mode = ORBIT_MODE_TRANSFER {
                set orbit_mode to ORBIT_MODE_FINAL.
            }
            _logWithT("Finished orbital correction burn.").
        }
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
        "setOrbitProfile", setOrbitProfile@
    ).
}
