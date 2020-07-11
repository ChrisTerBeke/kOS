// prevent typos
@LAZYGLOBAL OFF.

// copy the library scripts to the flight computer
deletepath("1:/lib").
createdir("1:/lib").
copypath("0:/lib/globals", "1:/lib/").
copypath("0:/lib/configure_staging", "1:/lib/").
copypath("0:/lib/countdown", "1:/lib/").
copypath("0:/lib/launch", "1:/lib/").
copypath("0:/lib/gravity_turn", "1:/lib/").
copypath("0:/lib/circularize", "1:/lib/").

// the main launch sequence
runpath("lib/globals").
runpath("lib/configure_staging", 5).
runpath("lib/countdown", 3).
runpath("lib/launch").
runpath("lib/gravity_turn").
runpath("lib/circularize").

// keep the script running to prevent loss of control
wait 1000.
