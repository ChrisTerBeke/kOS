runOncePath("programs/helpers/CalculateDeltaV").  // #include "../helpers/CalculateDeltaV.ks"
runOncePath("programs/helpers/CalculateRemainingBurnTime").  // #include "../helpers/CalculateRemainingBurnTime.ks"
runOncePath("programs/helpers/DebugLog").  // #include "../helpers/DebugLog.ks"
runOncePath("programs/helpers/DeployFairings").  // #include "../helpers/DeployFairings.ks"

function Circularize {

    parameter target_altitude.

    local burn_started is false.
    local burn_finished is false.
    local fairings_separated is false.
    local throttle_to is 0.

    function isComplete {
        return burn_finished.
    }
    
    function update {
        local burn_delta_v is calculateDeltaV(target_altitude).
        local burn_time_remaining is calculateRemainingBurnTime(burn_delta_v).

        // full throttle 50% before and 50% after apoapsis for max efficiency
        if eta:apoapsis <= (burn_time_remaining / 2) and not burn_started {
            set throttle_to to 1.
            set burn_started to true.
            debugLog("Starting circularization burn").
        }

        // reduce throttle towards end of burn to improve accuracy
        if ship:orbit:eccentricity < 0.02 {
            set throttle_to to 0.1.
        }

        // cut engines at end of burn
        if burn_started and burn_time_remaining <= 0 {
            set throttle_to to 0.
            set burn_finished to true.
            debugLog("Finished circularization burn").
        }

        // separate fairings when almost out of atmosphere
        if ship:altitude > (0.95 * ship:body:atm:height) and not fairings_separated {
            deployFairings().
            debugLog("Fairing separation").
        }
    }

    function getDirection {
        return ship:prograde.
    }

    function getThrottle {
        return throttle_to.
    }

    function getName {
        return "Circularize".
    }

    return lexicon(
        "isComplete", isComplete@,
        "update", update@,
        "getDirection", getDirection@,
        "getThrottle", getThrottle@,
        "getName", getName@
    ).
}
