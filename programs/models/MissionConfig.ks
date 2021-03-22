runOncePath("programs/models/Hohmann").  // #include "./Hohmann.ks"
runOncePath("programs/models/Launch").  // #include "./Launch.ks"

function MissionConfig {

    parameter mission_name.

    // load the config file based on the mission name
    // these files are expected to expose a global variable called MISSION_CONFIG
    // missions/default.ks is used as example and for IDE symbol typing
    local mission_file_name is "0:/programs/missions/" + mission_name + ".ks".
    runOncePath(mission_file_name).   // #include "../missions/default.ks"

    function getName {
        return MISSION_CONFIG["name"].
    }

    function getManeuvers {
        return MISSION_CONFIG["manveuvers"].
    }

    return lexicon(
        "getManeuvers", getManeuvers@,
        "getName", getName@
    ).
}
