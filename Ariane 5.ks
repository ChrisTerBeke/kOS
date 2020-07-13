// copy the library to the flight computer
deletepath("1:/lib").
copypath("0:/lib", "1:/lib").

// run the launch program
runpath("lib/launch", 140000, 0, 1, 0).
