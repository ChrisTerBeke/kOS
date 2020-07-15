// copy the library to the flight computer
deletepath("1:/lib").
copypath("0:/lib", "1:/lib").

// run the launch program
runpath("lib/launch", 120000, 0, 1, 0).
