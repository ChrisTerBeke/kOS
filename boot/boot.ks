// boot script
// finds the correct script for the current vessel and copies it to the flight computer as 'start.ks'
set script_path to "0:/" + ship:name + ".ks".
if exists(script_path) {
    print ("Copying " + script_path + " to flight computer. Execute with `run start.`.").
    copypath(script_path, "start.ks").
} else {
    print "Path " + script_path + " not found. Exiting.".
}
