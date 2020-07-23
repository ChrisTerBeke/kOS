runOncePath("programs/controllers/AbortController"). // #include "controllers/AbortController.ks"
runOncePath("programs/controllers/InputController"). // #include "controllers/InputController.ks"
runOncePath("programs/controllers/LaunchController"). // #include "controllers/LaunchController.ks"
runOncePath("programs/controllers/OrbitalController"). // #include "controllers/OrbitalController.ks"
runOncePath("programs/controllers/StagingController"). // #include "controllers/StagingController.ks"
runOncePath("programs/controllers/SteeringController"). // #include "controllers/SteeringController.ks"
runOncePath("programs/controllers/TelemetryController"). // #include "controllers/TelemetryController.ks"
runOncePath("programs/controllers/ThrottleController"). // #include "controllers/ThrottleController.ks"
runOncePath("programs/models/Mission"). // #include "models/Mission.ks"

// mission config file name
parameter mission_name.

// create controllers
local abort_controller is AbortController().
local input_controller is InputController().
local launch_controller is LaunchController().
local orbital_controller is OrbitalController().
local staging_controller is StagingController().
local steering_controller is SteeringController().
local telemetry_controller is TelemetryController().
local throttle_controller is ThrottleController().

// program modes
global PROGRAM_MODE_IDLE is 0.
global PROGRAM_MODE_LAUNCH is 1.
global PROGRAM_MODE_ORBIT is 2.
global PROGRAM_MODE_ABORT is 999.
local program_mode is PROGRAM_MODE_IDLE.
local program_finished is false.

// configure abort modes
local detect_loss_of_control_launch_modes is list(LAUNCH_MODE_VERTICAL_ASCENT, LAUNCH_MODE_GRAVITY_TURN).
local detect_insufficient_thrust_launch_modes is list(LAUNCH_MODE_VERTICAL_ASCENT, LAUNCH_MODE_GRAVITY_TURN).
on abort {
    set program_mode to PROGRAM_MODE_ABORT.
    abort_controller:doAbort().
    launch_controller:doAbort().
    orbital_controller:doAbort().
	staging_controller:doAbort().
	steering_controller:doAbort().
	throttle_controller:doAbort().
}

// configure the mission
local mission is Mission(input_controller:getMissionProfile(mission_name)).

// main loop
clearScreen.
until program_finished {

    // start launch sequence on enter
    if input_controller:enterPressed() and program_mode = PROGRAM_MODE_IDLE {
        launch_controller:setLaunchProfile(mission:getLaunchProfile()).
        set program_mode to PROGRAM_MODE_LAUNCH.
    }

    // go to orbit mode if we're already in a stable orbit or if the launch sequence was completed
    local in_stable_orbit is periapsis > 70000.
    if (in_stable_orbit and program_mode = PROGRAM_MODE_IDLE) or (launch_controller:isComplete() and program_mode = PROGRAM_MODE_LAUNCH) {
        orbital_controller:setOrbitProfile(mission:getOrbitProfile()).
        set program_mode to PROGRAM_MODE_ORBIT.
    }

    // configure controller activation
    abort_controller:setEnabled(program_mode > PROGRAM_MODE_IDLE).
    launch_controller:setEnabled(program_mode = PROGRAM_MODE_LAUNCH).
    orbital_controller:setEnabled(program_mode = PROGRAM_MODE_ORBIT).
    staging_controller:setEnabled(program_mode = PROGRAM_MODE_LAUNCH).
	steering_controller:setEnabled(program_mode > PROGRAM_MODE_IDLE).
    telemetry_controller:setEnabled(program_mode > PROGRAM_MODE_IDLE).
	throttle_controller:setEnabled(program_mode > PROGRAM_MODE_IDLE).

    // controller configuration for launch mode
    if program_mode = PROGRAM_MODE_LAUNCH {
        local launch_mode is launch_controller:getLaunchMode().
        local allow_staging is stage:number > mission:maxStageDuringLaunch().
        abort_controller:setAbortOnLossOfControl(detect_loss_of_control_launch_modes:contains(launch_mode)).
        abort_controller:setAbortOnInsufficientThrust(detect_insufficient_thrust_launch_modes:contains(launch_mode)).
        staging_controller:setAutoDetectStaging(launch_mode > LAUNCH_MODE_VERTICAL_ASCENT and allow_staging).
        staging_controller:setForceStaging(launch_mode = LAUNCH_MODE_COAST_TO_EDGE_OF_ATMOSPHERE and allow_staging and mission:stageAtEdgeOfAtmosphere()).
		steering_controller:setDirection(launch_controller:getDirection()).
		telemetry_controller:setCustomTelemetry(launch_controller:getTelemetry()).
		throttle_controller:setThrottle(launch_controller:getThrottle()).
    }

	// controller configuration for orbit mode
	if program_mode = PROGRAM_MODE_ORBIT {
        abort_controller:setAbortOnLossOfControl(false).
        abort_controller:setAbortOnInsufficientThrust(false).
        staging_controller:setAutoDetectStaging(false).
		steering_controller:setDirection(orbital_controller:getDirection()).
		telemetry_controller:setCustomTelemetry(orbital_controller:getTelemetry()).
		throttle_controller:setThrottle(orbital_controller:getThrottle()).
	}

    // pipe all messages to the telemetry controller
    telemetry_controller:addMessages(launch_controller:getMessages()).
    telemetry_controller:addMessages(staging_controller:getMessages()).

    // update all controllers
    abort_controller:update().
    input_controller:update().
    launch_controller:update().
    orbital_controller:update().
    staging_controller:update().
	steering_controller:update().
    telemetry_controller:update().

    // prevent KSP from locking up
    wait 0.05.
}
