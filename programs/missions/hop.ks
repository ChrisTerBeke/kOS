runOncePath("programs/models/CountDown").  // #include "../models/CountDown.ks"
runOncePath("programs/models/Hover").  // #include "../models/Hover.ks"

global MISSION_CONFIG is lexicon(
    "name", "default",
    "manveuvers", queue(
        CountDown(5),
        Hover(50)
    )
).
