// copy the library to the flight computer
deletepath("1:/lib").
copypath("0:/lib", "1:/lib").

// execute the launch program
local target_apoapsis is 140000.
local target_inclination is 0.
local stage_until is 5.
local roll is 270.
runpath("lib/launch", target_apoapsis, target_inclination, stage_until, roll).
