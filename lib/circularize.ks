// circularize the current orbit to the target periapsis
print "initializing circularization program".

// calculate the velocity we should have for a circular orbit at the apoapsis height
// also calculate the burn time so we can burn 1/2 before and 1/2 after the apoapsis
set targetOrbitalV to ship:body:radius * sqrt(9.8 / (ship:body:radius + apoapsis)).
set maxDeltaV to ship:maxThrust / ship:mass.
set apoapsisV to sqrt(ship:body:mu * ((2 / (ship:body:radius + apoapsis)) - (1 / ship:obt:semimajoraxis))).
set deltaV to (targetOrbitalV - apoapsisV).
set timeToBurn to deltaV / maxDeltaV.

print "calculated circularization burn: " + timeToBurn + " seconds".

// perform the burn
rcs on.
lock steering to ship:prograde.
wait until eta:apoapsis < (timeToBurn / 2).
lock throttle to 1.
wait until ship:velocity:orbit:mag >= targetOrbitalV.
lock throttle to 0.

print "finished circularizing orbit, shutting down engines".
