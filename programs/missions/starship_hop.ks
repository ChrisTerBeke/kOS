runOncePath("programs/models/Hover").  // #include "../models/Hover.ks"

global MISSION_CONFIG is lexicon(
    "name", "default",
    "manveuvers", queue(
        Hover(150)
    )
).
