parameter mission_name is "falcon_9_test.json".
deletepath("1:/programs").
copypath("0:/programs", "1:/programs").
runPath("programs/main", mission_name).
