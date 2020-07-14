// copy the library to the flight computer
deletepath("1:/lib").
copypath("0:/lib", "1:/lib").

// run the launch program
runpath("lib/launch", 140000, 0, 5, 270).
wait 5.
stage. // deploy fairings and launch escape system
wait 5.
lights on.
panels on.
