function WaitUntil {

    parameter target_time.

    function totalDeltaV {
        return 0.
    }

    function nextBurnRemainingTime {
        return 0.
    }

    function isComplete {
        return time:seconds >= target_time:seconds.
    }

    function update {
        // nothing to do here
    }

    function getDirection {
        return ship:orbit:prograde.
    }

    function getThrottle {
        return 0.
    }

    return lexicon(
        "totalDeltaV", totalDeltaV@,
        "nextBurnRemainingTime", nextBurnRemainingTime@,
        "isComplete", isComplete@,
        "update", update@,
        "getDirection", getDirection@,
        "getThrottle", getThrottle@
    ).
}
