function Mission {

    parameter input_lex is lexicon().

    function getLaunchProfile {
        if not input_lex:hasKey("launch") {
            return lexicon("target_altitude", 120000, "target_inclination", 0, "roll", 0).
        }
        return input_lex["launch"].
    }

    function maxStageDuringLaunch {
        if not input_lex:hasKey("launch") {
            return 0.
        }
        if not input_lex["launch"]:hasKey("max_launch_stage") {
            return 0.
        }
        return input_lex["launch"]["max_launch_stage"].
    }

    function stageAtEdgeOfAtmosphere {
        if not input_lex:hasKey("launch") {
            return false.
        }
        if not input_lex["launch"]:hasKey("force_staging_at_edge_of_atmosphere") {
            return false.
        }
        return input_lex["launch"]["force_staging_at_edge_of_atmosphere"].
    }

    function getManeuvers {
        local result is list().
        if not input_lex:hasKey("maneuvers") {
            return result.
        }
        // TODO: better input checking
        return input_lex["maneuvers"].
    }

    return lexicon(
        "getLaunchProfile", getLaunchProfile@,
        "maxStageDuringLaunch", maxStageDuringLaunch@,
        "stageAtEdgeOfAtmosphere", stageAtEdgeOfAtmosphere@,
        "getManeuvers", getManeuvers@
    ).
}
