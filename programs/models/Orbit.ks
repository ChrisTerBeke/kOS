runOncePath("programs/helpers/CalculateEccentricity"). // #include "../helpers/CalculateEccentricity.ks"

function Orbit {

    parameter input_apoapsis.
    parameter input_periapsis.
    parameter input_inclination.

    function getApoapsis {
        return input_apoapsis.
    }

    function getPeriapsis {
        return input_periapsis.
    }

    function getInclination {
        return input_inclination.
    }

    function getEccentricity {
        return calculateEccentricity(input_apoapsis, input_periapsis).
    }

    return lexicon(
        "getApoapsis", getApoapsis@,
        "getPeriapsis", getPeriapsis@,
        "getInclination", getInclination@,
        "getEccentricity", getEccentricity@
    ).
}
