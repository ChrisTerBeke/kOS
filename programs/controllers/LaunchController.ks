runOncePath("programs/helpers/CalculateHeading").  // #include "../helpers/CalculateHeading.ks"
runOncePath("programs/helpers/CalculateLaunchAzimuth").  // #include "../helpers/CalculateLaunchAzimuth.ks"
runOncePath("programs/helpers/CalculateOrbitalSpeed").  // #include "../helpers/CalculateOrbitalSpeed.ks"
runOncePath("programs/helpers/CalculateRemainingBurnTime").  // #include "../helpers/CalculateRemainingBurnTime.ks"
runOncePath("programs/helpers/GetThrustForStage").  // #include "../helpers/GetThrustForStage.ks"
runOncePath("programs/helpers/ReleaseLaunchClamps").  // #include "../helpers/ReleaseLaunchClamps.ks"

// controller modes
global LAUNCH_MODE_PRE_LAUNCH is -1.
global LAUNCH_MODE_COUNTDOWN is 0.
global LAUNCH_MODE_LIFTOFF is 1.
global LAUNCH_MODE_VERTICAL_ASCENT is 2.
global LAUNCH_MODE_GRAVITY_TURN is 3.
global LAUNCH_MODE_COAST_TO_EDGE_OF_ATMOSPHERE is 4.
global LAUNCH_MODE_CIRCULARIZATION_BURN is 5.
global LAUNCH_MODE_COMPLETED is 6.
global LAUNCH_MODE_ABORT is 999.

function LaunchController {

    // launch parameters
    parameter target_altitude is 100000.
    parameter target_inclination is 0.
    parameter roll is 0.

    local is_enabled is false.
    local message_list is list().

    // launch constants
    local turn_start_altitude is 1500.
    local turn_end_pitch_degrees is 10.
    local max_orbit_eccentricity is 0.05.
    local countdown_from is 5.
    local launch_location is ship:geoPosition.
    local launch_azimuth is calculateLaunchAzimuth(target_altitude, target_inclination, launch_location).
    local target_orbital_speed is calculateOrbitalSpeed(target_altitude).

    // mission variables
    local launch_mode is LAUNCH_MODE_PRE_LAUNCH.
    local launch_complete is false.
	local launch_time is 0.
    lock mission_elapsed_time to time:seconds - launch_time.

    // vehicle control variables
    local throttle_to is 0.
    local steer_to is calculateHeading(90, 90, roll).

    // countdown variables
    local countdown_ignition_started is false.

    // gravity turn variables
    local turn_end_altitude is 0.
    local turn_exponent is 0.

    function update {
        if not is_enabled {
            return.
        }
        if launch_mode = LAUNCH_MODE_PRE_LAUNCH { _preLaunch(). }
        if launch_mode = LAUNCH_MODE_COUNTDOWN { _countDown(). }
        if launch_mode = LAUNCH_MODE_LIFTOFF { _liftOff(). }
        if launch_mode = LAUNCH_MODE_VERTICAL_ASCENT { _verticalAscent(). }
        if launch_mode = LAUNCH_MODE_GRAVITY_TURN { _gravityTurn(). }
        if launch_mode = LAUNCH_MODE_COAST_TO_EDGE_OF_ATMOSPHERE { _coast(). }
        if launch_mode = LAUNCH_MODE_CIRCULARIZATION_BURN { _circularize(). }
        if launch_mode = LAUNCH_MODE_COMPLETED { _complete(). }
        if launch_mode = LAUNCH_MODE_ABORT { _abort(). }
    }

    function setEnabled {
        parameter value.
        if is_enabled = value {
			return.
		}
        set is_enabled to value.
    }

    function getLaunchMode {
        return launch_mode.
    }

    function isComplete {
        return launch_complete.
    }

    function doAbort {
        set launch_mode to LAUNCH_MODE_ABORT.
    }

    function getMessages {
        local messages is message_list:copy().
        message_list:clear().
        return messages.
    }

	function getDirection {
		return steer_to.
	}

	function getThrottle {
		return throttle_to.
	}

	function getTelemetry {
		return lexicon(
			"Direction", getDirection(),
			"Throttle", getThrottle()
		).
	}

    function _preLaunch {
        // TODO: check vehicle TWR and other critical parameters to ensure successful launch
        set ship:control:pilotmainthrottle to 0.
        sas off.
        rcs off.
        set launch_time to time:seconds + countdown_from.
        _goToNextMode().
        _logWithT("Pre-launch checklist complete.").
    }

    function _countDown {

        // main engine ignition at T-3
        if mission_elapsed_time >= -3 and not countdown_ignition_started {
            set throttle_to to 1.
            stage. // start engines
            set countdown_ignition_started to true.
            _logWithT("Main engine ignition sequence started.").
        }

        // lift-off at T-0
        if mission_elapsed_time >= 0 {
            releaseLaunchClamps().
            set launch_time to time:seconds.
            lock mission_elapsed_time to time:seconds - launch_time.
            _goToNextMode().
            _logWithT("Liftoff!").
        }
    }

    function _liftOff {
        local launch_twr is getThrustForStage() / (ship:mass * ship:body:mu / (altitude + ship:body:radius) ^ 2).
        set turn_end_altitude to (0.128 * ship:body:atm:height * launch_twr) + (0.5 * ship:body:atm:height).
        set turn_exponent to max(1 / (2.5 * launch_twr - 1.7), 0.25).
        _goToNextMode().
        _logWithT("Initiating vertical ascent program.").
    }

    function _verticalAscent {
        // TODO: gradual roll program
        if altitude > turn_start_altitude {
            set steer_to to calculateHeading(90, 90, ROLL).
            _goToNextMode().
            _logWithT("Initiating gravity turn program.").
        }
    }

    function _gravityTurn {
        // TODO: throttling around max Q

        // calculate pitch
        local steer_to_pitch is max(90 - (((altitude - turn_start_altitude) / (turn_end_altitude - turn_start_altitude)) ^ turn_exponent * 90), turn_end_pitch_degrees).

        // calculate heading
        if abs(ship:orbit:inclination - abs(target_inclination)) > 2 {
            set steer_to_direction to launch_azimuth.
        } else if target_inclination >= 0 and vAng(vxcl(ship:up:vector, ship:facing:vector), ship:north:vector) <= 90{
            set steer_to_direction to (90 - target_inclination) - 2 * (abs(target_inclination) - ship:orbit:inclination).
        } else {
            set steer_to_direction to (90 - target_inclination) + 2 * (abs(target_inclination) - ship:orbit:inclination).
        }
        local tmp_heading is calculateHeading(steer_to_direction, steer_to_pitch, ROLL).

        // limit angle of attack depending on aerodynamic pressure
        if ship:q > 0 {
            set angle_limit to max(3, min(90, 5 * ln(0.9 / ship:q))).
        } else {
            set angle_limit to 90.
        }

        // adjust heading depending on AoA limit
        set angle_to_prograde to vAng(ship:srfprograde:vector, tmp_heading:vector).
        if angle_to_prograde > angle_limit {
            local ascent_heading_limited to (angle_limit / angle_to_prograde * (tmp_heading:vector:normalized - ship:srfPrograde:vector:normalized)) + ship:srfprograde:vector:normalized.
            set tmp_heading to ascent_heading_limited:direction.
        }

        // steer to the calculated direction, pich and roll
        set steer_to to tmp_heading.

        // reduce throttle when nearing target apoapsis so we can fine-tune better
        if (target_altitude - apoapsis) < 2000 {
            set throttle_to to 0.2.
        }

        // gravity turn end conditions
        if apoapsis >= target_altitude {
            set throttle_to to 0.
            _goToNextMode().
            _logWithT("Reached target apoapsis. Coasting to edge of atmosphere.").
        }
    }

    function _coast {
        // TODO: re-raise apoapsis if it fell due to atmospheric drag
        set steer_to to ship:srfprograde.

        // out of apmosphere detected
        if altitude > ship:body:atm:height {
            _goToNextMode().
            _logWithT("Reached edge of atmosphere. Fairings separated.").
        }
    }

    function _circularize {
        set steer_to to ship:prograde.
        local burn_time_remaining is calculateRemainingBurnTime(target_orbital_speed).
        if burn_time_remaining < 0.5 and (ship:orbit:eccentricity < max_orbit_eccentricity) {
            // schedule end of burn and cut engines
            local burn_end_time to time:seconds + burn_time_remaining.
            wait until time:seconds > burn_end_time.
            set throttle_to to 0.
            _goToNextMode().
            _logWithT("Circularization burn complete.").
        } else if eta:apoapsis <= (burn_time_remaining / 2) {
            // full throttle 50% before and 50% after apoapsis
            set throttle_to to 1.
        }
    }

    function _complete {
        _logWithT("Launch program completed.").
        set launch_complete to true.
    }

    function _abort {
        _logWithT("Launch program aborted.").
        set launch_complete to true.
        set is_enabled to false.
    }

    function _logWithT {
        local parameter text.
        local line is "T+" + round(mission_elapsed_time, 2) + ": " + text.
        message_list:add(line).
    }

    function _goToNextMode {
        set launch_mode to launch_mode + 1.
    }

    return lexicon(
        "getLaunchMode", getLaunchMode@,
        "doAbort", doAbort@,
        "update", update@,
        "setEnabled", setEnabled@,
        "isComplete", isComplete@,
        "getMessages", getMessages@,
		"getDirection", getDirection@,
		"getThrottle", getThrottle@,
		"getTelemetry", getTelemetry@
    ).
}
