runOncePath("programs/models/Orbit"). // #include "./Orbit.ks"
runOncePath("programs/helpers/CalculateDeltaV"). // #include "../helpers/CalculateDeltaV.ks"

function Hohmann {
    // TODO: split into 2 'orbit change burn' objects?

    parameter target_altitude.
    // TODO: allow inclination change

    local ORBIT_MODE_IDLE is -1.
    local ORBIT_MODE_STARTING is 0.
    local ORBIT_MODE_TRANSFER is 1.
    local ORBIT_MODE_FINAL is 2.
    local current_mode is ORBIT_MODE_IDLE.

    local current_orbit is Orbit(apoapsis, periapsis, ship:orbit:inclination).
    local transfer_orbit is Orbit(target_altitude, current_orbit:getApoapsis(), ship:orbit:inclination).
    local final_orbit is Orbit(target_altitude, transfer_orbit:getApoapsis(), ship:orbit:inclination).

    local target_orbit is current_orbit.
    local burn_started is false.
    local throttle_to is 0.

    // calculate the total DeltaV needed for all burns in this transfer
    function totalDeltaV {
        local starting_to_transfer_delta_v is calculateDeltaV(current_orbit:getApoapsis(), transfer_orbit:getApoapsis(), transfer_orbit:getPeriapsis()).
        local transfer_to_final_delta_v is calculateDeltaV(transfer_orbit:getApoapsis(), final_orbit:getApoApsis(), final_orbit:getPeriapsis()).
        return starting_to_transfer_delta_v + transfer_to_final_delta_v.
    }

    // get the approximate time needed to execute the upcoming burn
    function nextBurnRemainingTime {
        local burn_delta_v is calculateDeltaV(altitude, target_orbit:getApoapsis(), target_orbit:getPeriapsis()).
        return calculateRemainingBurnTime(burn_delta_v).
    }

    function isComplete {
        return current_mode = ORBIT_MODE_FINAL.
    }

    function start {
        _planNextBurn().
    }

    function update {

        local remaining_burn_time is nextBurnRemainingTime().

        if remaining_burn_time < 0.05 {
            return.
        }

        // start burning at 50% of our total burn time before apoapsis for highest precision
        if eta:apoapsis <= (remaining_burn_time / 2) and not burn_started {
            set throttle_to to 1.
            set burn_started to true.
        }

        // reduce throttle towards end of burn to improve accuracy
        if burn_started and abs(ship:orbit:eccentricity - target_orbit:getEccentricity()) < 0.02 {
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
        set current_mode to current_mode + 1.

        // re-calculate orbits as they might have changed depending on actual current orbit
        set current_orbit to Orbit(apoapsis, periapsis, ship:orbit:inclination).
        set transfer_orbit to Orbit(target_altitude, current_orbit:getApoapsis(), ship:orbit:inclination).
        set final_orbit to Orbit(target_altitude, transfer_orbit:getApoapsis(), ship:orbit:inclination).

        // set the target orbit for the new mode (idle -> starting -> transfer -> final)
        if current_mode = ORBIT_MODE_STARTING {
            set target_orbit to transfer_orbit.
        } else if current_mode = ORBIT_MODE_TRANSFER {
            set target_orbit to final_orbit.
        }
    }

    return lexicon(
        "totalDeltaV", totalDeltaV@,
        "nextBurnRemainingTime", nextBurnRemainingTime@,
        "isComplete", isComplete@,
        "start", start@,
        "update", update@,
        "getDirection", getDirection@,
        "getThrottle", getThrottle@
    ).
}
