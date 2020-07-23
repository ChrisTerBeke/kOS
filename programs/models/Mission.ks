function Mission {

    parameter input_lex is lexicon().

    function getLaunchProfile {
        if not input_lex:hasKey("launch") {
            return lexicon("target_altitude", 120000, "target_inclination", 0).
        }
        return input_lex["launch"].
    }

    function getOrbitProfile {
        if not input_lex:hasKey("orbit") {
            return lexicon("target_apoapsis", apoapsis, "target_periapsis", periapsis).
        }
        return input_lex["orbit"].
    }

    function maxStageDuringLaunch {
        if not input_lex:hasKey("vehicle") {
            return 0.
        }
        if not input_lex["vehicle"]:hasKey("max_launch_stage") {
            return 0.
        }
        return input_lex["vehicle"]["max_launch_stage"].
    }

    function stageAtEdgeOfAtmosphere {
        if not input_lex:hasKey("vehicle") {
            return false.
        }
        if not input_lex["vehicle"]:hasKey("force_staging_at_edge_of_atmosphere") {
            return false.
        }
        return input_lex["vehicle"]["force_staging_at_edge_of_atmosphere"].
    }

    return lexicon(
        "getLaunchProfile", getLaunchProfile@,
        "getOrbitProfile", getOrbitProfile@,
        "maxStageDuringLaunch", maxStageDuringLaunch@,
        "stageAtEdgeOfAtmosphere", stageAtEdgeOfAtmosphere@
    ).
}
