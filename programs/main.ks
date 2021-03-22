runOncePath("programs/controllers/AbortController"). // #include "controllers/AbortController.ks"
runOncePath("programs/controllers/InputController"). // #include "controllers/InputController.ks"
runOncePath("programs/controllers/SequenceController"). // #include "controllers/SequenceController.ks"
runOncePath("programs/controllers/SteeringController"). // #include "controllers/SteeringController.ks"
runOncePath("programs/controllers/TelemetryController"). // #include "controllers/TelemetryController.ks"
runOncePath("programs/controllers/ThrottleController"). // #include "controllers/ThrottleController.ks"
runOncePath("programs/models/MissionConfig"). // #include "models/MissionConfig.ks"

// mission config file name
parameter mission_name.
local mission_config is MissionConfig(mission_name).

// create controllers
local abort_controller is AbortController().
local input_controller is InputController().
local sequence_controller is SequenceController(mission_config).
local steering_controller is SteeringController().
local telemetry_controller is TelemetryController(mission_name).
local throttle_controller is ThrottleController().

// program modes
global PROGRAM_MODE_IDLE is 0.
global PROGRAM_MODE_ACTIVE is 1.
global PROGRAM_MODE_ABORT is 999.
local program_mode is PROGRAM_MODE_IDLE.
local program_finished is false.

// configure abort actions
// TODO: abort detection
// local detect_loss_of_control_launch_modes is list(LAUNCH_MODE_VERTICAL_ASCENT, LAUNCH_MODE_GRAVITY_TURN).
// local detect_insufficient_thrust_launch_modes is list(LAUNCH_MODE_VERTICAL_ASCENT, LAUNCH_MODE_GRAVITY_TURN).
on abort {
    set program_mode to PROGRAM_MODE_ABORT.
    abort_controller:doAbort().
    sequence_controller:doAbort().
	steering_controller:doAbort().
	throttle_controller:doAbort().
}

// main loop
clearScreen.
until program_finished {

    // start mission sequence on enter
    if input_controller:enterPressed() and program_mode = PROGRAM_MODE_IDLE {
        set program_mode to PROGRAM_MODE_ACTIVE.
    }

    // finish the program after orbital insertion is complete
    if sequence_controller:isComplete() and program_mode = PROGRAM_MODE_ACTIVE {
        set program_finished to true.
    }

    // configure controller activation
    abort_controller:setEnabled(program_mode > PROGRAM_MODE_IDLE).
    sequence_controller:setEnabled(program_mode = PROGRAM_MODE_ACTIVE).
	steering_controller:setEnabled(program_mode = PROGRAM_MODE_ACTIVE).
    telemetry_controller:setEnabled(program_mode = PROGRAM_MODE_ACTIVE).
	throttle_controller:setEnabled(program_mode = PROGRAM_MODE_ACTIVE).

    // control vehicle when in active mode
    if program_mode = PROGRAM_MODE_ACTIVE {
        // TODO: abort detection
        // abort_controller:setAbortOnLossOfControl(detect_loss_of_control_launch_modes:contains(launch_mode)).
        // abort_controller:setAbortOnInsufficientThrust(detect_insufficient_thrust_launch_modes:contains(launch_mode)).
        steering_controller:setDirection(sequence_controller:getDirection()).
        throttle_controller:setThrottle(sequence_controller:getThrottle()).
    }

    // log telemetry
    telemetry_controller:setTelemetry(sequence_controller:getTelemetry()).

    // update all controllers
    abort_controller:update().
    input_controller:update().
    sequence_controller:update().
	steering_controller:update().
    telemetry_controller:update().

    // prevent KSP from locking up
    wait 0.2.
}
clearScreen.
