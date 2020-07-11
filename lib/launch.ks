// generic launch script
declare local parameter roll is 270.

print "liftoff".
rcs off.
lock steering to heading(90, 90, roll).
lock throttle to 1.
stage.
