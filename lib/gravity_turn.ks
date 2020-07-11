// generic gravity turn script
declare local parameter target_apoapsis is 140000.
declare local parameter start_turn_at_speed is 100.
declare local parameter turn_speed_step is 50.
declare local parameter max_pitch is 90.
declare local parameter pitch_step is 5.
declare local parameter final_pitch is 10.
declare local parameter roll is 270.
declare local parameter direction is 90.

print "initializing gravity turn program".

until ship:apoapsis > target_apoapsis {
    // TODO: implement max Q throttling
    set speed to ship:velocity:surface:mag.
    if speed > start_turn_at_speed {
        set speed_inc to (speed - start_turn_at_speed) / turn_speed_step.
        set pitch to max(round(max_pitch - (speed_inc * pitch_step), 1), final_pitch).
        lock steering to heading(direction, pitch, roll).
        print "adjusted pitch to " + pitch.
    }
    wait 1.
}

print "reached target apoapsis, shutting down engines".

lock throttle to 0.
