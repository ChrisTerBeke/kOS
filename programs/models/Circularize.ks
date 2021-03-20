runOncePath("programs/helpers/CalculateDeltaV").  // #include "../helpers/CalculateDeltaV.ks"
runOncePath("programs/helpers/CalculateRemainingBurnTime").  // #include "../helpers/CalculateRemainingBurnTime.ks"

function Circularize {

    parameter target_altitude.

    local burn_started is false.
    local steer_to is ship:prograde.
    local throttle_to is 0.

    function isComplete {
        // TODO: maybe separate boolean is needed?
        return ship:periapsis >= target_altitude.
    }
    
    function update {
        local burn_delta_v is calculateDeltaV(target_altitude).
        local burn_time_remaining is calculateRemainingBurnTime(burn_delta_v).

        // full throttle 50% before and 50% after apoapsis for max efficiency
        if eta:apoapsis <= (burn_time_remaining / 2) and not burn_started {
            set throttle_to to 1.
            set burn_started to true.
        }

        // reduce throttle towards end of burn to improve accuracy
        if ship:orbit:eccentricity < 0.02 {
            set throttle_to to 0.1.
        }

        // cut engines at end of burn
        if burn_started and burn_time_remaining <= 0 {
            set throttle_to to 0.
        }
    }

    function getDirection {
        return steer_to.
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
