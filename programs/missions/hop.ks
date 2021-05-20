runOncePath("programs/models/starship/Hop").  // #include "../models/starship/Hop.ks"

global MISSION_CONFIG is lexicon(
    "name", "default",
    "maneuvers", queue(
        Hop(2000)
    )
).
