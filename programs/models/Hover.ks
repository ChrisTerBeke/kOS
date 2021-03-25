runOncePath("programs/helpers/CalculateUpDirection").  // #include "../helpers/CalculateUpDirection.ks"

function Hover {

    parameter target_altitude.

    local throttle_to is 1.

    function isComplete {
        return false.
    }

    function update {


        // TODO
    }

    function getDirection {
        return calculateUpDirection().
    }

    function getThrottle {
        return throttle_to.
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
