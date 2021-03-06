function WaitUntil {

    parameter target_time.

    function isComplete {
        return time:seconds >= target_time:seconds.
    }

    function update {}

    function getDirection {
        if ship:altitude > ship:body:atm:height {
            return prograde.
        }
        return srfPrograde.
    }

    function getThrottle {
        return 0.
    }

    function getName {
        return "Wait until".
    }

    return lexicon(
        "isComplete", isComplete@,
        "update", update@,
        "getDirection", getDirection@,
        "getThrottle", getThrottle@,
        "getName", getName@
    ).
}
