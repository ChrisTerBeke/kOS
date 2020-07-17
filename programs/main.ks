// imports
runOncePath("programs/controllers/AbortController"). // #include "controllers/AbortController.ks"
runOncePath("programs/controllers/LaunchController"). // #include "controllers/LaunchController.ks"
runOncePath("programs/controllers/OrbitalController"). // #include "controllers/OrbitalController.ks"
runOncePath("programs/controllers/StagingController"). // #include "controllers/StagingController.ks"
runOncePath("programs/controllers/TelemetryController"). // #include "controllers/TelemetryController.ks"

// default main program
parameter target_altitude.
parameter target_inclination.
parameter stop_staging_at.
parameter roll.

// configure controllers
local abort_controller is AbortController().
local launch_controller is LaunchController(target_altitude, target_inclination, roll).
local orbital_controller is OrbitalController(target_altitude).
local staging_controller is StagingController().
local telemetry_controller is TelemetryController().

local detect_loss_of_control_launch_modes is list(LAUNCH_MODE_VERTICAL_ASCENT, LAUNCH_MODE_GRAVITY_TURN).
local detect_insufficient_thrust_launch_modes is list(LAUNCH_MODE_VERTICAL_ASCENT, LAUNCH_MODE_GRAVITY_TURN, LAUNCH_MODE_CIRCULARIZATION_BURN).

// program modes
global PROGRAM_MODE_IDLE is 0.
global PROGRAM_MODE_LAUNCH is 1.
global PROGRAM_MODE_ORBIT is 2.
global PROGRAM_MODE_ABORT is 999.

local program_mode is PROGRAM_MODE_IDLE.
local program_finished is false.

// setup triggers
on abort {
    set program_mode to PROGRAM_MODE_ABORT.
    abort_controller:doAbort().
    launch_controller:doAbort().
    orbital_controller:doAbort().
    staging_controller:doAbort().
}

// main loop
clearScreen.
until program_finished {

    // detect terminal input to switch program modes
    if terminal:input:haschar {
        local input is terminal:input:getchar().
        // start in launch mode
        if input = "l" and program_mode = PROGRAM_MODE_IDLE {
            set program_mode to PROGRAM_MODE_LAUNCH.
        }
        // start in orbit mode
        if input = "o" and program_mode = PROGRAM_MODE_IDLE {
            set program_mode to PROGRAM_MODE_ORBIT.
        }
    }

    // after launch we go to orbit mode automatically
    if launch_controller:isComplete() {
        set program_mode to PROGRAM_MODE_ORBIT.
    }

    // configure controller activation
    abort_controller:setEnabled(program_mode > PROGRAM_MODE_IDLE).
    launch_controller:setEnabled(program_mode = PROGRAM_MODE_LAUNCH).
    orbital_controller:setEnabled(program_mode = PROGRAM_MODE_ORBIT).
    staging_controller:setEnabled(program_mode = PROGRAM_MODE_LAUNCH).
    telemetry_controller:setEnabled(program_mode > PROGRAM_MODE_IDLE).

    // controller configuration for launch mode
    if program_mode = PROGRAM_MODE_LAUNCH {
        local launch_mode is launch_controller:getLaunchMode().
        abort_controller:setAbortOnLossOfControl(detect_loss_of_control_launch_modes:contains(launch_mode)).
        abort_controller:setAbortOnInsufficientThrust(detect_insufficient_thrust_launch_modes:contains(launch_mode)).
        staging_controller:setAutoDetectStaging(launch_mode > LAUNCH_MODE_VERTICAL_ASCENT and stage:number > stop_staging_at).
        staging_controller:setForceStaging(launch_mode = LAUNCH_MODE_COAST_TO_EDGE_OF_ATMOSPHERE and stage:number > stop_staging_at).
    }

    // pipe all messages to the telemetry controller
    telemetry_controller:addMessages(launch_controller:getMessages()).
    telemetry_controller:addMessages(staging_controller:getMessages()).

    // update all controllers
    abort_controller:update().
    launch_controller:update().
    orbital_controller:update().
    staging_controller:update().
    telemetry_controller:update().

    // prevent KSP from locking up
    wait 0.1.
}
