// generic launch script
parameter target_apoapsis is 140000.
parameter target_inclination is 0.
parameter stage_until is 0.
parameter roll is 270.

// configure global mission parameters
set turn_start_altitude to 1500.
set booster_separation_delay to 2.
set stage_separation_delay to 3.
set throttle_pid to 0.004.
set throttle_pid_delta to 0.004.
set limit_to_terminal_velocity to false.
set orbit_max_error_percentage to 5.
set steeringManager:rollpid:kp to 0.
set steeringManager:rollpid:ki to 0.
set countdown_from to 12.
set launch_abort_mode to 999.

// calculated parameters
set launch_location to ship:geoposition.
set inertial_azimuth to arcSin(max(min(cos(target_inclination) / cos(launch_location:lat), 1), -1)).
set target_orbit_speed to sqrt(ship:body:mu / (target_apoapsis + ship:body:radius)).
set rotate_velocity_x to target_orbit_speed * sin(inertial_azimuth) - (6.2832 * ship:body:radius / ship:body:rotationperiod).
set rotate_velocity_y to target_orbit_speed * cos(inertial_azimuth).
set launch_azimuth to arctan(rotate_velocity_x / rotate_velocity_y).

// parameters (re)calculated during flight
set num_parts to ship:parts:length.
set launch_time to time:seconds + countdown_from.
lock mission_elapsed_time to time:seconds - launch_time.
set steer_to to heading(90, 90, roll).
set steer_heading to launch_azimuth.
set throttle_to to 0.
set launch_complete to false.
set launch_mode to 0.
set launch_twr to 0.
set turn_end_altitude to 0.
set turn_exponent to 0.
set countdown_thrust_reached to false.
set countdown_ignition_started to false.
set countdown_hold to false.
set ignition_time to time:seconds.
set broke_30_seconds_to_apoapsis to false.
set apoapsis_boost_burn to false.
set node_delta_velocity to 0.
set next_node to false.
set should_stage to false.
set staging_in_progress to false.
set stage_at_time to time:seconds.
set staging_engine_ignore_list to list().

// configure for launch
checkLaunchClamps().
set ship:control:pilotmainthrottle to 0.
set config:ipu to 500.
sas off.
rcs off.
lock throttle to throttle_to.
lock steering to steer_to.

// configure fairing separation at 95% atmosphere
when altitude > (ship:body:atm:height * 0.95) then {
    separateFairings().
    printToLog("Fairing separation.").
}

// configure abort detection
on abort {
    set launch_mode to launch_abort_mode.
}

// execute launch program
until launch_complete {

    // countdown program
    if launch_mode = 0 {

        print "Launch in " + mission_elapsed_time.

        // hold countdown as long as we're not at 95% thrust
        // TODO: do not perform this check if 1st stage only has solid fuel
        if not countdown_thrust_reached {
            set engine_info to getActiveEngineInfo().
            if engine_info[0] < 0.95 * engine_info[1] {
                set countdown_hold to true.
                printToLog("Holding until 95% thrust.").
            } else {
                set countdown_thrust_reached to true.
                set countdown_hold to false.
            }
        }

        // main engine ignition at T-3.
        if mission_elapsed_time >= -3 and not countdown_ignition_started {
            doStage().
            set ignition_time to time:seconds.
            set throttle_to to (time:seconds - ignition_time) / 2.
            set countdown_ignition_started to true.
            printToLog("Main engine ignition sequence started.").
        }

        if mission_elapsed_time >= 0 and not countdown_hold {
            set throttle_to to 1.
            doStage(). // release launch clamps
            set launch_time to time:seconds.
            lock mission_elapsed_time to time:seconds - launch_time.
            goToNextLaunchMode().
            printToLog("Liftoff!").
        }

        if mission_elapsed_time >= 2 and countdown_hold {
            printToLog("Aborting launch due to countdown hold.").
            set launch_mode to launch_abort_mode.
            // TODO: shut down engines etc.
        }
    }

    // prepare for vertical ascent
    if launch_mode = 1 {
        wait 0.
        set engine_info to getActiveEngineInfo().
        set launch_twr to engine_info[1] / (ship:mass * body:mu / (altitude + body:radius) ^ 2).
        set turn_end_altitude to 0.128 * ship:body:atm:height * launch_twr + 0.5 * ship:body:atm:height.
        set turn_exponent to max(1 / (2.5 * launch_twr - 1.7), 0.25).
        goToNextLaunchMode().
        printToLog("Initiating vertical ascent program.").
    }

    // vertical ascent program
    if launch_mode = 2 {
        if altitude > turn_start_altitude {
            set steer_to to heading(90, 90, roll).
            goToNextLaunchMode().
            printToLog("Initiating gravity turn program.").
        }
    }

    // gravity turn program
    if launch_mode = 3 {

        // steer to prograde while staging for smooth separation
        if staging_in_progress {
            set ascent_heading to ship:prograde.
        } else {

            // calculate gravity turn desired pitch
            set trajectory_pitch to max(90 - (((altitude - turn_start_altitude) / (turn_end_altitude - turn_start_altitude)) ^ turn_exponent * 90), 0).
            set steer_pitch to trajectory_pitch.

            // keep time to apoapsis above 30 seconds during ascent once above 30 seconds
            if broke_30_seconds_to_apoapsis and eta:apoapsis < 30 {
                set steer_pitch to steer_pitch + (30 - eta:apoapsis).
            } else if eta:apoapsis > 30 and not broke_30_seconds_to_apoapsis {
                set broke_30_seconds_to_apoapsis to true.
            }

            // steer towards the target inclination
            if abs(ship:orbit:inclination - abs(target_inclination)) > 2 {
                set steer_heading to launch_azimuth.
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

            set ascent_heading to heading(steer_heading, steer_pitch).

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
        }

        set steer_to to ascent_heading.

        // TODO: throttling around max Q

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
    if launch_mode = 4 {
        set steer_to to ship:srfprograde.

        // we're done here
        if altitude > ship:body:atm:height {
            goToNextLaunchMode().
            printToLog("Reached edge of atmosphere. Now coasting.").
        }

        // raise our apoapsis if it fell below our target apoapsis (due to atmospheric drag)
        if apoapsis < (1 - orbit_max_error_percentage / 100) * target_apoapsis and not apoapsis_boost_burn {
            set throttle_to to 0.1.
            printToLog("Apoapsis dropped below target. Starting correction burn.").
        } else if apoapsis > target_apoapsis and apoapsis_boost_burn {
            set throttle_to to 0.
            printToLog("Target apoapsis reached. Stopping correction burn.").
        }
    }

    // set up circularization node
    if launch_mode = 5 {
        set throttle_to to 0.
        printToLog("Calculating circularization maneuver.").
        set periapsis_radius to periapsis + ship:body:radius.
        set apoapsis_radius to apoapsis + ship:body:radius.
        set node_delta_velocity to sqrt(ship:body:mu / (apoapsis_radius)) * (1 - sqrt(2 * periapsis_radius / (periapsis_radius / apoapsis_radius))).
        set next_node to node(time:seconds + eta:apoapsis, 0, 0, node_delta_velocity).
        add next_node.
        goToNextLaunchMode().
        printToLog("Circularization maneuver created.").
    }

    // drop stage if fuel is nearly depleted
    if launch_mode = 6 {
        set throttle_to to 0.
        set stage_delta_velocity to getDeltaVelocityForstage().
        if stage_delta_velocity >= 0 {
            if (stage_delta_velocity < node_delta_velocity* 0.5 and node_delta_velocity > 200) or stage_delta_velocity < 100 {
                set should_stage to true.
                printToLog("Current stage low on fuel. Stage separation configured.").
            }
        }
        if not staging_in_progress {
            goToNextLaunchMode().
        }
    }

    // steer to circularization node
    if launch_mode = 7 {
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
            // TODO: support reaching stable orbit after missing circularization at apoapsis instead of aborting
            printToLog("Failed to steer to circularization maneuver. Aborting mission.").
            set launch_mode to launch_abort_mode.
            abort on.
        }
    }

    // execute circularization node
    if launch_mode = 8 {

        // overshot apoapsis but stable orbit reached, stop burning to prevent worse final orbit
        if apoapsis > (1 + orbit_max_error_percentage / 100) * target_apoapsis and periapsis > ship:body:atm:height {
            set throttle_to to 0.
            goToNextLaunchMode().
        }

        lock burn_time_remaining to next_node:deltav:mag / max(availablethrust / ship:mass, 0.001).
        if burn_time_remaining > 2 {
            set throttle_to to 1.
            set steer_to to next_node.
        } else {
            unlock steering.
            sas on. // prevent spinning at end of circularization burn
            printToLog("Circularization burn nearly complete. Fine-tuning remainder.").
            wait 0.001.
            set time_to_complete_burn to burn_time_remaining - 0.1.
            set burn_end_time to time:seconds + time_to_complete_burn.
            wait until time:seconds > burn_end_time.
            set throttle_to to 0.
            unlock burn_time_remaining.
            remove next_node.
            goToNextLaunchMode().
            printToLog("Circularization burn complete.").
        }
    }

    // launch sequence completed
    if launch_mode = 9 {
        printToLog("Finished launch sequence. Controls now back to manual.").
        set launch_complete to true.
    }

    // launch sequence was aborted in any of the above modes
    if launch_mode = launch_abort_mode {
        set throttle_to to 0.
        set ship:control:neutralize to true.
        unlock steering.
        remove next_node.
        sas on.
        printToLog("Launch aborted.").
        break.
    }

    // staging detection
    if launch_mode > 0 and stage:number >= stage_until {

        // auto-staging triggers
        if launch_mode = 3 or launch_mode = 8 and not staging_in_progress {
            list engines in engine_list.
            for engine in engine_list {

                // we still have thrust, this is just booster separation
                if engine:flamout and maxThrust >= 0.1 {
                    set stage_at_time to time:seconds + stage_separation_delay.
                    set staging_in_progress to true.
                    break.
                } else if engine:flamout and maxThrust < 0.1 {
                    set throttle_to to 0.
                    set stage_at_time to time:seconds + stage_separation_delay.
                    set staging_in_progress to true.
                    break.
                }
            }
        }

        // staging was configured in any launch mode above
        if should_stage {
            set throttle_to to 0.
            set stage_at_time to time:seconds + stage_separation_delay.
            set should_stage to false.
            set staging_in_progress to true.
        }

        // execute staging
        if time:seconds >= stage_at_time and staging_in_progress {
            doStage().
            set staging_in_progress to false.
        }

        // new stage has no thrust, we need to stage one more time
        // otherwise we ignite the engines (if we're not coasting)
        if ship:maxthrust < 0.01 {
            set stage_at_time to time:seconds + stage_separation_delay.
        } else {
            if launch_mode = 3 or launch_mode = 8 {
                set throttle_to to 1.
            }
            set staging_in_progress to false.
        }

        // TODO: support ullage staging with separation boosters
    }

    // auto-abort detection scenarios
    if launch_mode = 3 and vAng(ship:facing:vector, steer_to:vector) > 45 and mission_elapsed_time > 5 {
        set launch_mode to launch_abort_mode.
        printToLog("Detected loss of control. Aborting mission.").
    }

    if launch_mode < 5 and launch_mode > 0 and verticalSpeed < -1.0 {
        set launch_mode to launch_abort_mode.
        printToLog("Detected lack of vertical velocity. Aborting mission.").
    }

    if ship:parts:length < num_parts and stage:ready {
        set launch_mode to launch_abort_mode.
        printToLog("Detecting vehicle breaking up. Aborting missin.").
    }

    // prevent KSP from locking up
    wait 0.01.
}

// check if all launch clamps are on the same stage
function checkLaunchClamps {
    set launch_clamp_stage to 999.
    for part in ship:parts {
        if part:modules:contains("LaunchClamp") {
            if launch_clamp_stage = 999 {
                set launch_clamp_stage to part:stage.
            } else if part:stage <> launch_clamp_stage {
                print "Not all launch clamps are on the same stage.".
                print "Please re-configure the staging setup.".
                wait until false.
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
function getDeltaVelocityForstage {

    // unable to calculate DeltaV when there are complex fuel lines in place
    for part in ship:parts {
        if part: modules:contains("CModeFuelLine") {
            return -1.
        }
    }

    // calculate the total fuel mass (stage:resources does not work as it returns fuel from non-active stages as well)
    local fuel_mass is stage:liguidfuel * 0.005 + stage:oxidier * 0.005 + stage:solidfuel * 0.0075.

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

    // deltaV calculation as Isp*g*ln(m0/m1).
    return average_specific_impulse * 9.81 * ln(ship:mass / (ship:mass - fuel_mass)).
}

// switch to the next launch mode in the program
function goToNextLaunchMode {
    set launch_mode to launch_mode + 1.
}

// print text to the mission log
function printToLog {
    local parameter text.
    local line is "T" + round(mission_elapsed_time, 2) + ": " + text.
    log line to launch_log.txt.
    print line.
}

// go to the next stage
function doStage {
    stage.
    set num_parts to ship:parts:length.
}

// seprate the fairings (currently on action group 8)
function separateFairings {
    toggle ag8.
    set num_parts to ship:parts:length.
}
