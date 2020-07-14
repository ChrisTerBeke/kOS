// generic launch script

// mission parameters
parameter target_apoapsis.
parameter target_inclination.
parameter stage_until.
parameter roll.

// global mission constants
set TURN_START_ALTITUDE to 1500.
set STAGE_SEPARATION_DELAY to 2.
set ORBIT_MAX_ERROR_PERCENTAGE to 5.
set COUNTDOWN_FROM to 5.
set LAUNCH_LOCATION to ship:geoposition.
set INERTIAL_AZIMUTH to arcSin(max(min(cos(target_inclination) / cos(LAUNCH_LOCATION:lat), 1), -1)).
set TARGET_ORBITAL_SPEED to sqrt(ship:body:mu / (target_apoapsis + ship:body:radius)).
set ROTATIONAL_VELOCITY_X to TARGET_ORBITAL_SPEED * sin(INERTIAL_AZIMUTH) - (6.2832 * ship:body:radius / ship:body:rotationperiod).
set ROTATIONAL_VELOCTY_Y to TARGET_ORBITAL_SPEED * cos(INERTIAL_AZIMUTH).
set LAUNCH_AZIMUTH to arctan(ROTATIONAL_VELOCITY_X / ROTATIONAL_VELOCTY_Y).

// launch mode constants
set LAUNCH_MODE_PRE_LAUNCH to -1.
set LAUNCH_MODE_COUNTDOWN to 0.
set LAUNCH_MODE_LIFTOFF to 1.
set LAUNCH_MODE_VERTICAL_ASCENT to 2.
set LAUNCH_MODE_GRAVITY_TURN to 3.
set LAUNCH_MODE_COAST_TO_EDGE_OF_ATMOSPHERE to 4.
set LAUNCH_MODE_SETUP_CIRCULARIZATION_BURN to 5.
set LAUNCH_MODE_STEER_TO_CIRCULARIZATION_BURN to 6.
set LAUNCH_MODE_EXECUTE_CIRCULARIZATION_BURN to 7.
set LAUNCH_MODE_COMPLETED to 8.
SET LAUNCH_MODE_ABORT to 999.

// global control variables
set num_parts to ship:parts:length.
set throttle_to to 0.
set steer_to to heading(90, 90, roll).
set steer_heading to LAUNCH_AZIMUTH.

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
set broke_30_seconds_to_apoapsis to false.
set apoapsis_boost_burn to false.

// circularization burn variables
set node_delta_velocity to 0.
set next_node to false.

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

        // lift-ff at T-0
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
        set engine_info to getActiveEngineInfo().
        set launch_twr to engine_info[1] / (ship:mass * body:mu / (altitude + body:radius) ^ 2).
        set turn_end_altitude to 0.128 * ship:body:atm:height * launch_twr + 0.5 * ship:body:atm:height.
        set turn_exponent to max(1 / (2.5 * launch_twr - 1.7), 0.25).
        goToNextLaunchMode().
        printToLog("Initiating vertical ascent program.").
    }

    // vertical ascent program
    // TODO: roll program
    if launch_mode = LAUNCH_MODE_VERTICAL_ASCENT {
        if altitude > TURN_START_ALTITUDE {
            set steer_to to heading(90, 90, roll).
            goToNextLaunchMode().
            printToLog("Initiating gravity turn program.").
        }
    }

    // gravity turn program
    // TODO: gradual turn start
    // TODO: configurable turn end angle
    // TODO: throttling around max Q
    if launch_mode = LAUNCH_MODE_GRAVITY_TURN {

        // calculate gravity turn desired pitch
        set trajectory_pitch to max(90 - (((altitude - TURN_START_ALTITUDE) / (turn_end_altitude - TURN_START_ALTITUDE)) ^ turn_exponent * 90), 0).
        set steer_pitch to trajectory_pitch.

        // keep time to apoapsis above 30 seconds during ascent once above 30 seconds
        if broke_30_seconds_to_apoapsis and eta:apoapsis < 30 {
            set steer_pitch to steer_pitch + (30 - eta:apoapsis).
        } else if eta:apoapsis > 30 and not broke_30_seconds_to_apoapsis {
            set broke_30_seconds_to_apoapsis to true.
        }

        // steer towards the target inclination
        if abs(ship:orbit:inclination - abs(target_inclination)) > 2 {
            set steer_heading to LAUNCH_AZIMUTH.
        } else {
            if target_inclination >= 0 {
                if vAng(vxcl(ship:up:vector, ship:facing:vector), ship:north:vector) <= 90 {
                    set steer_heading to (90 - target_inclination) - 2 * (abs(target_inclination) - ship:orbit:inclination).
                } else {
                    set steer_heading to (90 - target_inclination) + 2 * (abs(target_inclination) - ship:orbit:inclination).
                }
            } else if target_inclination < 0 {
                set steer_heading to (90 - target_inclination) + 2 * (abs(target_inclination) - ship:orbit:inclination).
            }
        }

        set ascent_heading to heading(steer_heading, steer_pitch, roll).

        // don't pitch too far from prograde while under high aerodynamic pressure
        if ship:q > 0 {
            set angle_limit to max(3, min(90, 5 * ln(0.9 / ship:q))).
        } else {
            set angle_limit to 90.
        }
        set angle_to_prograde to vAng(ship:srfprograde:vector, ascent_heading:vector).
        if angle_to_prograde > angle_limit {
            set ascent_heading_limited to (angle_limit / angle_to_prograde * (ascent_heading:vector:normalized - ship:srfPrograde:vector:normalized)) + ship:srfprograde:vector:normalized.
            set ascent_heading to ascent_heading_limited:direction.
        }

        set steer_to to ascent_heading.

        // gravity turn end conditions
        if apoapsis > target_apoapsis {
            set throttle_to to 0.
            set trajectory_pitch to 0.
            set steer_pitch to 0.
            goToNextLaunchMode().
            printToLog("Reached target apoapsis. Coasting to edge of atmosphere.").
        }
    }

    // coast to edge of atmosphere
    // TODO: drop fairings when out of atmosphere (auto-detect fairing parts and launch escape system?)
    if launch_mode = LAUNCH_MODE_COAST_TO_EDGE_OF_ATMOSPHERE {
        set steer_to to ship:srfprograde.

        // we're done here
        if altitude > ship:body:atm:height {
            goToNextLaunchMode().
            printToLog("Reached edge of atmosphere.").
        }

        // raise our apoapsis if it fell below our target apoapsis (due to atmospheric drag)
        if apoapsis < (1 - ORBIT_MAX_ERROR_PERCENTAGE / 100) * target_apoapsis and not apoapsis_boost_burn {
            set throttle_to to 0.1.
            printToLog("Apoapsis dropped below target. Starting correction burn.").
        } else if apoapsis > target_apoapsis and apoapsis_boost_burn {
            set throttle_to to 0.
            printToLog("Target apoapsis reached. Stopping correction burn.").
        }
    }

    // set up circularization node
    if launch_mode = LAUNCH_MODE_SETUP_CIRCULARIZATION_BURN {
        set throttle_to to 0.
        printToLog("Calculating circularization maneuver.").
        set periapsis_radius to periapsis + ship:body:radius.
        set apoapsis_radius to apoapsis + ship:body:radius.
        set node_delta_velocity to sqrt(ship:body:mu / apoapsis_radius) * (1 - sqrt(2 * periapsis_radius / (periapsis_radius + apoapsis_radius))).
        set next_node to node(time:seconds + eta:apoapsis, 0, 0, node_delta_velocity).
        add next_node.
        goToNextLaunchMode().
        printToLog("Circularization maneuver created.").
    }

    // steer to circularization node
    // TODO: support reaching stable orbit after missing circularization at apoapsis instead of aborting
    if launch_mode = LAUNCH_MODE_STEER_TO_CIRCULARIZATION_BURN {
        set throttle_to to 0.
        printToLog("Steering to circularization maneuver").
        set steer_to to next_node.
        set steer_error_x to next_node:burnvector:normalized:x - facing:vector:normalized:x.
        set steer_error_y to next_node:burnvector:normalized:y - facing:vector:normalized:y.
        set steer_error_z to next_node:burnvector:normalized:z - facing:vector:normalized:z.
        set steer_error_total to sqrt(steer_error_x ^ 2 + steer_error_y ^ 2 + steer_error_z ^ 2).
        if steer_error_total > 0.1 {
            goToNextLaunchMode().
        } else {
            printToLog("Failed to steer to circularization maneuver. Aborting mission.").
            set launch_mode to LAUNCH_MODE_ABORT.
        }
    }

    // execute circularization node
    if launch_mode = LAUNCH_MODE_EXECUTE_CIRCULARIZATION_BURN {

        // overshot apoapsis but stable orbit reached, stop burning to prevent worse final orbit
        if apoapsis > ((1 + ORBIT_MAX_ERROR_PERCENTAGE / 100) * target_apoapsis) and periapsis > ship:body:atm:height {
            set throttle_to to 0.
            goToNextLaunchMode().
            printToLog("Overshot target apoapsis but reached stable orbit nonetheless.").
        }

        // perform burn if we're closer than 1/2 from the total burn time from it
        lock burn_time_remaining to next_node:deltav:mag / max(ship:availablethrust / ship:mass, 0.001).
        if next_node:eta <= (burn_time_remaining / 2) {
            set throttle_to to 1.
            set steer_to to next_node.

            // finalize burn
            if burn_time_remaining < 0.1 {
                unlock steering.
                sas on.
                set burn_end_time to time:seconds + burn_time_remaining.
                wait until time:seconds > burn_end_time.
                set throttle_to to 0.
                remove next_node.
                goToNextLaunchMode().
                printToLog("Circularization burn complete.").
            }
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
        remove next_node.
        sas on.
        abort on.
        printToLog("Launch program aborted.").
        break.
    }

    // staging detection
    if launch_mode > LAUNCH_MODE_COUNTDOWN and stage:number > stage_until {

        // auto-staging triggers
        if (launch_mode = LAUNCH_MODE_GRAVITY_TURN or launch_mode = LAUNCH_MODE_EXECUTE_CIRCULARIZATION_BURN) and not staging_in_progress {
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

    if launch_mode > LAUNCH_MODE_LIFTOFF and launch_mode < LAUNCH_MODE_SETUP_CIRCULARIZATION_BURN and verticalSpeed < -1.0 {
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

// get current thrust, max thrust, avg ISP and max DOT
function getActiveEngineInfo {
    list engines in engine_list.
    local current_thrust is 0.
    local max_thrust is 0.
    local max_flow_rate is 0.
    local average_specific_impulse is 0.

    for engine in engine_list {
        if engine:ignition {
            set max_thrust to max_thrust + engine:availablethrust.
            set current_thrust to current_thrust + engine:thrust.
            if not engine:isp = 0 {
                set max_flow_rate to max_flow_rate + current_thrust / engine:isp.
            }
        }
    }

    if max_flow_rate > 0 {
        set average_specific_impulse to current_thrust / max_flow_rate.
    }

    return list(current_thrust, max_thrust, average_specific_impulse, max_flow_rate).
}

// get the remaining delta velocity for the curren stage
function getDeltaVelocityForStage {

    // unable to calculate DeltaV when there are complex fuel lines in place
    for part in ship:parts {
        if part:modules:contains("CModeFuelLine") {
            return -1.
        }
    }

    // calculate the total fuel mass (stage:resources does not work as it returns fuel from non-active stages as well)
    local resources is stage:resourceslex.
    local fuel_mass is (resources["liquidfuel"]:amount * 0.005) + (resources["oxidizer"]:amount * 0.005) + (resources["solidfuel"]:amount * 0.0075).

    // calculate total available thrust and flow rate
    list engines in engine_list.
    local total_thrust is 0.
    local mass_flow_rate is 0.
    local average_specific_impulse is 0.

    for engine in engine_list {
        if engine:ignition {
            set total_thrust to total_thrust + engine:availablethrust.
            if engine:isp <> 0 {
                set mass_flow_rate to mass_flow_rate + (engine:availablethrust / engine:isp).
            }
        }
    }

    if mass_flow_rate <> 0 {
        set average_specific_impulse to total_thrust / mass_flow_rate.
    }

    local delta_velocity is average_specific_impulse * constant:g0 * ln(ship:mass / (ship:mass - fuel_mass)).
    return delta_velocity.
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
