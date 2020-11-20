runOncePath("programs/models/Orbit"). // #include "./Orbit.ks"
runOncePath("programs/helpers/CalculateDeltaV"). // #include "../helpers/CalculateDeltaV.ks"
runOncePath("programs/helpers/CalculateRemainingBurnTime"). // #include "../helpers/CalculateRemainingBurnTime.ks"

function OrbitChange {

	parameter target_apoapsis.
	parameter target_periapsis.
	// TODO: allow inclination change

	local ORBIT_MODE_IDLE is -1.
    local ORBIT_MODE_STARTING is 0.
    local ORBIT_MODE_FINAL is 1.
	local current_mode is ORBIT_MODE_IDLE.

	local current_orbit is Orbit(apoapsis, periapsis, ship:orbit:inclination).
	local final_orbit is Orbit(target_apoapsis, target_periapsis, ship:orbit:inclination).

	local active_orbit is current_orbit.
	local burn_started is false.
    local throttle_to is 0.

	// get the approximate time needed to execute the upcoming burn
    function nextBurnRemainingTime {
        local burn_delta_v is calculateDeltaV(altitude, active_orbit:getApoapsis(), active_orbit:getPeriapsis()).
        return calculateRemainingBurnTime(burn_delta_v).
    }

	function isComplete {
		return current_mode = ORBIT_MODE_FINAL.
	}

	function update {
		local remaining_burn_time is nextBurnRemainingTime().

		if not burn_started and remaining_burn_time < 0.05 {
			_planNextBurn().
			return.
		}

        // start burning at 50% of our total burn time before apoapsis for highest precision
		if eta:apoapsis <= (remaining_burn_time / 2) and not burn_started {
			set throttle_to to 1.
            set burn_started to true.
		}

		// reduce throttle towards end of burn to improve accuracy
        if burn_started and abs(ship:orbit:eccentricity - active_orbit:getEccentricity()) < 0.02 {
            set throttle_to to 0.1.
        }

		if burn_started and remaining_burn_time < 0.05 {
            set throttle_to to 0.
            set burn_started to false.
            _planNextBurn().
        }
	}

	function getDirection {
		return ship:prograde.
	}

	function getThrottle {
		return throttle_to.
	}

	function _planNextBurn {
		if current_mode = ORBIT_MODE_FINAL {
            return.
        }
		set current_mode to current_mode + 1.

		// re-calculate orbits as they might have changed
		set current_orbit to Orbit(apoapsis, periapsis, ship:orbit:inclination).
		set final_orbit to Orbit(target_apoapsis, target_periapsis, ship:orbit:inclination).

		if current_mode = ORBIT_MODE_STARTING {
			set active_orbit to final_orbit.
		}
	}

	return lexicon(
		"nextBurnRemainingTime", nextBurnRemainingTime@,
        "isComplete", isComplete@,
        "update", update@,
        "getDirection", getDirection@,
        "getThrottle", getThrottle@
	).
}
