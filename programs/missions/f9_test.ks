runOncePath("programs/models/Hohmann").  // #include "../models/Hohmann.ks"
runOncePath("programs/models/Launch").  // #include "../models/Launch.ks"

global MISSION_CONFIG is lexicon(
    "name", "f9_test",
    "maneuvers", queue(
        Launch(120000, 51.2, 0),
        Hohmann(140000)
    )
).
