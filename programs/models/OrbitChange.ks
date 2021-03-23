runOncePath("programs/helpers/CalculateDeltaV"). // #include "../helpers/CalculateDeltaV.ks"
runOncePath("programs/helpers/CalculateEccentricity"). // #include "../helpers/CalculateEccentricity.ks"
runOncePath("programs/helpers/CalculateRemainingBurnTime"). // #include "../helpers/CalculateRemainingBurnTime.ks"

function OrbitChange {

	parameter target_apoapsis.
	parameter target_periapsis.
	// TODO: implement steering and DeltaV logic for inclination changes
	
	local target_eccentricity is calculateEccentricity(target_apoapsis, target_periapsis).
	local burn_started is false.
	local burn_finished is false.
    local throttle_to is 0.

	function isComplete {
		return burn_finished.
	}

	function update {
		local burn_delta_v is calculateDeltaV(altitude, target_apoapsis, target_periapsis).
		local burn_time_remaining is calculateRemainingBurnTime(burn_delta_v).

		if not burn_started and burn_time_remaining < 0.05 {
			set burn_finished to true.
			return.
		}

        // start burning at 50% of our total burn time before apoapsis for highest precision
		if eta:apoapsis <= (burn_time_remaining / 2) and not burn_started {
			set throttle_to to 1.
            set burn_started to true.
		}

		// reduce throttle towards end of burn to improve accuracy
		// TODO: is eccentricity really the best method of detecting this?
        if burn_started and abs(ship:orbit:eccentricity - target_eccentricity) < 0.02 {
            set throttle_to to 0.1.
        }

		if burn_started and burn_time_remaining < 0.05 {
            set throttle_to to 0.
            set burn_started to false.
        }
	}

	function getDirection {
		return prograde.
	}

	function getThrottle {
		return throttle_to.
	}

	return lexicon(
        "isComplete", isComplete@,
        "update", update@,
        "getDirection", getDirection@,
        "getThrottle", getThrottle@
	).
}
