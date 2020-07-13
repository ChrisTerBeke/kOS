// boot script
// finds the correct script for the current vessel and copies it to the flight computer as 'start.ks'
set script_path to "0:/" + ship:name + ".ks".
if exists(script_path) {
    copypath(script_path, "start.ks").
    print "copied " + script_path + " to flight computer.".
    print "Execute with `run start.`".
} else {
    print "Path " + script_path + " not found.".
}
