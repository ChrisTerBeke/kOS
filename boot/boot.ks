// boot script
wait until ship:unpacked.
set script_path to "0:/start.ks".
if exists(script_path) {
    copypath(script_path, "start.ks").
    print "copied " + script_path + " to flight computer.".
    print "Execute with `run start(mission_name).`".
} else {
    print "Path " + script_path + " not found.".
}
