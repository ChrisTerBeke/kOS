// generic launch script

// mission parameters
parameter TARGET_ALTITUDE.
parameter TARGET_INCLINATION.
parameter STAGE_UNTIL.
parameter ROLL.

// global mission constants
set TURN_START_ALTITUDE to 1500.
set TURN_END_PITCH_DEGREES to 10.
set STAGE_SEPARATION_DELAY to 2.
set COUNTDOWN_FROM to 5.
set LAUNCH_LOCATION to ship:geoposition.
set INERTIAL_AZIMUTH to arcSin(max(min(cos(TARGET_INCLINATION) / cos(LAUNCH_LOCATION:lat), 1), -1)).
set TARGET_ORBITAL_SPEED to sqrt(ship:body:mu * ((2 / (ship:body:radius + TARGET_ALTITUDE)) - (1 / (ship:body:radius + TARGET_ALTITUDE)))).
set ROTATIONAL_VELOCITY_X to TARGET_ORBITAL_SPEED * sin(INERTIAL_AZIMUTH) - (6.2832 * ship:body:radius / ship:body:rotationperiod).
set ROTATIONAL_VELOCITY_Y to TARGET_ORBITAL_SPEED * cos(INERTIAL_AZIMUTH).
set LAUNCH_AZIMUTH to arctan(ROTATIONAL_VELOCITY_X / ROTATIONAL_VELOCITY_Y).

// launch mode constants
set LAUNCH_MODE_PRE_LAUNCH to -1.
set LAUNCH_MODE_COUNTDOWN to 0.
set LAUNCH_MODE_LIFTOFF to 1.
set LAUNCH_MODE_VERTICAL_ASCENT to 2.
set LAUNCH_MODE_GRAVITY_TURN to 3.
set LAUNCH_MODE_COAST_TO_EDGE_OF_ATMOSPHERE to 4.
set LAUNCH_MODE_CIRCULARIZATION_BURN to 5.
set LAUNCH_MODE_COMPLETED to 6.
SET LAUNCH_MODE_ABORT to 999.

// global control variables
set num_parts to ship:parts:length.
set throttle_to to 0.
set steer_to to heading(90, 90, ROLL).

// global mission variables
set launch_time to time:seconds + COUNTDOWN_FROM.
set launch_mode to LAUNCH_MODE_PRE_LAUNCH.
set launch_complete to false.
lock mission_elapsed_time to time:seconds - launch_time.

// global staging variables
set should_stage to false.
set staging_in_progress to false.
set stage_at_time to time:seconds.

// countdown variables
set countdown_ignition_started to false.

// gravity turn variables
set turn_end_altitude to 0.
set turn_exponent to 0.

// TODO: figure this out so we can make roll program work
set steeringManager:rollpid:kp to 0.
set steeringManager:rollpid:ki to 0.

// detect manual abort
on abort {
    set launch_mode to LAUNCH_MODE_ABORT.
}

// main launch sequence loop
until launch_complete {

    // pre-launch sequence
    if launch_mode = LAUNCH_MODE_PRE_LAUNCH {
        checkLaunchClamps().
        set ship:control:pilotmainthrottle to 0.
        set config:ipu to 500.
        sas off.
        rcs off.
        lock throttle to throttle_to.
        lock steering to steer_to.
        goToNextLaunchMode().
        printToLog("Pre-launch checklist complete.").
    }

    // countdown program
    if launch_mode = LAUNCH_MODE_COUNTDOWN {

        // main engine ignition at T-3
        if mission_elapsed_time >= -3 and not countdown_ignition_started {
            set throttle_to to 1.
            doStage(). // start engines
            set countdown_ignition_started to true.
            printToLog("Main engine ignition sequence started.").
        }

        // lift-off at T-0
        if mission_elapsed_time >= 0 {
            doStage(). // release launch clamps
            set launch_time to time:seconds.
            lock mission_elapsed_time to time:seconds - launch_time.
            goToNextLaunchMode().
            printToLog("Liftoff!").
        }
    }

    // prepare for vertical ascent
    if launch_mode = LAUNCH_MODE_LIFTOFF {
        set launch_twr to getAvailableThrustForCurrentStage() / (ship:mass * ship:body:mu / (altitude + ship:body:radius) ^ 2).
        set turn_end_altitude to (0.128 * ship:body:atm:height * launch_twr) + (0.5 * ship:body:atm:height).
        set turn_exponent to max(1 / (2.5 * launch_twr - 1.7), 0.25).
        goToNextLaunchMode().
        printToLog("Initiating vertical ascent program.").
    }

    // vertical ascent program
    // TODO: roll program
    if launch_mode = LAUNCH_MODE_VERTICAL_ASCENT {
        if altitude > TURN_START_ALTITUDE {
            set steer_to to heading(90, 90, ROLL).
            goToNextLaunchMode().
            printToLog("Initiating gravity turn program.").
        }
    }

    // gravity turn program
    // TODO: throttling around max Q
    if launch_mode = LAUNCH_MODE_GRAVITY_TURN {

        // calculate pitch
        set steer_to_pitch to max(90 - (((altitude - TURN_START_ALTITUDE) / (turn_end_altitude - TURN_START_ALTITUDE)) ^ turn_exponent * 90), TURN_END_PITCH_DEGREES).

        // calculate heading
        if abs(ship:orbit:inclination - abs(TARGET_INCLINATION)) > 2 {
            set steer_to_direction to LAUNCH_AZIMUTH.
        } else if TARGET_INCLINATION >= 0 and vAng(vxcl(ship:up:vector, ship:facing:vector), ship:north:vector) <= 90{
            set steer_to_direction to (90 - TARGET_INCLINATION) - 2 * (abs(TARGET_INCLINATION) - ship:orbit:inclination).
        } else {
            set steer_to_direction to (90 - TARGET_INCLINATION) + 2 * (abs(TARGET_INCLINATION) - ship:orbit:inclination).
        }
        set tmp_heading to heading(steer_to_direction, steer_to_pitch, ROLL).

        // limit angle of attack depending on aerodynamic pressure
        if ship:q > 0 {
            set angle_limit to max(3, min(90, 5 * ln(0.9 / ship:q))).
        } else {
            set angle_limit to 90.
        }

        // adjust heading depending on AoA limit
        set angle_to_prograde to vAng(ship:srfprograde:vector, tmp_heading:vector).
        if angle_to_prograde > angle_limit {
            set ascent_heading_limited to (angle_limit / angle_to_prograde * (tmp_heading:vector:normalized - ship:srfPrograde:vector:normalized)) + ship:srfprograde:vector:normalized.
            set tmp_heading to ascent_heading_limited:direction.
        }

        // steer to the calculated direction, pich and roll
        set steer_to to tmp_heading.

        // reduce throttle when nearing target apoapsis so we can fine-tune better
        if (TARGET_ALTITUDE - apoapsis) < 2000 {
            set throttle_to to 0.2.
        }

        // gravity turn end conditions
        if apoapsis >= TARGET_ALTITUDE {
            set throttle_to to 0.
            goToNextLaunchMode().
            printToLog("Reached target apoapsis. Coasting to edge of atmosphere.").
        }
    }

    // coast to edge of atmosphere
    // TODO: drop fairings when out of atmosphere (auto-detect fairing parts and launch escape system?)
    // TODO: re-raise apoapsis if it fell due to atmospheric drag
    // TODO: drop stage if low on fuel
    if launch_mode = LAUNCH_MODE_COAST_TO_EDGE_OF_ATMOSPHERE {
        set steer_to to ship:srfprograde.
        if altitude > ship:body:atm:height {
            goToNextLaunchMode().
            printToLog("Reached edge of atmosphere.").
        }
    }

    // circularization burn
    if launch_mode = LAUNCH_MODE_CIRCULARIZATION_BURN {
        set steer_to to ship:prograde.
        set burn_time_remaining to abs(TARGET_ORBITAL_SPEED - ship:velocity:orbit:mag) / max((ship:availablethrust / ship:mass), 0.001).
        if burn_time_remaining < 0.1 {
            // schedule end of burn and cut engines
            set burn_end_time to time:seconds + burn_time_remaining.
            wait until time:seconds > burn_end_time.
            set throttle_to to 0.
            goToNextLaunchMode().
            printToLog("Circularization burn complete.").
        } else if burn_time_remaining < 1 {
            // gradually reduce throttle to increase accuracy
            set throttle_to to max(burn_time_remaining, 0.1).
        } else if eta:apoapsis <= (burn_time_remaining / 2) {
            // full throttle 50% before and 50% after apoapsis
            set throttle_to to 1.
        }
    }

    // launch sequence completed
    if launch_mode = LAUNCH_MODE_COMPLETED {
        printToLog("Finished launch sequence. Controls now back to manual.").
        set launch_complete to true.
    }

    // launch sequence was aborted in any of the above modes
    if launch_mode = LAUNCH_MODE_ABORT {
        set throttle_to to 0.
        set ship:control:neutralize to true.
        unlock steering.
        sas on.
        abort on.
        printToLog("Launch program aborted.").
        break.
    }

    // staging detection
    if launch_mode > LAUNCH_MODE_COUNTDOWN and stage:number > STAGE_UNTIL {

        // auto-staging triggers
        if (launch_mode = LAUNCH_MODE_GRAVITY_TURN or launch_mode = LAUNCH_MODE_CIRCULARIZATION_BURN) and not staging_in_progress {
            list engines in engine_list.
            for engine in engine_list {
                if engine:flameout {
                    set stage_at_time to time:seconds + STAGE_SEPARATION_DELAY.
                    set staging_in_progress to true.
                    printToLog("Detected engine flameout. Staging required.").
                    break.
                }
            }
        }

        // staging was configured in any launch mode above
        if should_stage {
            set should_stage to false.
            set stage_at_time to time:seconds + STAGE_SEPARATION_DELAY.
            set staging_in_progress to true.
            printToLog("Stage separation requested.").
        }

        // execute staging
        if time:seconds >= stage_at_time and staging_in_progress {
            doStage().
            set staging_in_progress to false.
            printToLog("Stage separation confirmed.").
        }

        // new stage has no thrust, we need to stage one more time
        if not staging_in_progress and ship:maxthrust < 0.01 {
            set stage_at_time to time:seconds + STAGE_SEPARATION_DELAY.
            set staging_in_progress to true.
            printToLog("No thrust detected on current stage. Staging required.").
        }
    }

    // auto-abort detection scenarios
    if launch_mode = LAUNCH_MODE_GRAVITY_TURN and vAng(ship:facing:vector, steer_to:vector) > 45 and mission_elapsed_time > 5 {
        set launch_mode to LAUNCH_MODE_ABORT.
        printToLog("Detected loss of control. Aborting mission.").
    }

    if launch_mode > LAUNCH_MODE_LIFTOFF and launch_mode < LAUNCH_MODE_CIRCULARIZATION_BURN and verticalSpeed < -1.0 {
        set launch_mode to LAUNCH_MODE_ABORT.
        printToLog("Detected lack of vertical velocity. Aborting mission.").
    }

    if ship:parts:length < num_parts and stage:ready {
        set launch_mode to LAUNCH_MODE_ABORT.
        printToLog("Detecting vehicle breaking up. Aborting mission.").
    }

    // prevent KSP from locking up
    wait 0.1.
}

// check if all launch clamps are on the same stage
function checkLaunchClamps {
    set launch_clamp_stage to -1.
    for part in ship:parts {
        if part:modules:contains("LaunchClamp") {
            if launch_clamp_stage = -1 {
                set launch_clamp_stage to part:stage.
            } else if part:stage <> launch_clamp_stage {
                print "Not all launch clamps are on the same stage.".
                print "Please re-configure the staging setup.".
                break.
            }
        }
    }
}

// get the available thrust of all engines on the curren stage
function getAvailableThrustForCurrentStage {
    list engines in engine_list.
    local available_thrust is 0.
    for engine in engine_list {
        if engine:ignition {
            set available_thrust to available_thrust + engine:availablethrust.
        }
    }
    return available_thrust.
}

// switch to the next launch mode in the program
function goToNextLaunchMode {
    set launch_mode to launch_mode + 1.
}

// print text to the mission log
function printToLog {
    local parameter text.
    local line is "T+" + round(mission_elapsed_time, 2) + ": " + text.
    print line.
}

// go to the next stage
function doStage {
    stage.
    set num_parts to ship:parts:length.
}
