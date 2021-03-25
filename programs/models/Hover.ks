function Hover {

    parameter target_altitude.

    function isComplete {
        // TODO
    }

    function update {
        // TODO
    }

    function getDirection {
        // TODO
    }

    function getThrottle {
        // TODO
    }

    function getName {
        return "Hover".
    }

    return lexicon(
        "isComplete", isComplete@,
        "update", update@,
        "getDirection", getDirection@,
        "getThrottle", getThrottle@,
        "getName", getName@
    ).
}
