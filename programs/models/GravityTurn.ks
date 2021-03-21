runOncePath("programs/helpers/CalculateHeading").  // #include "../helpers/CalculateHeading.ks"
runOncePath("programs/helpers/CheckEngineFlameOut").  // #include "../helpers/CheckEngineFlameOut.ks"
runOncePath("programs/helpers/DebugLog").  // #include "../helpers/DebugLog.ks"
runOncePath("programs/helpers/GetThrustForStage").  // #include "../helpers/GetThrustForStage.ks"

function GravityTurn {

    parameter roll.
    parameter gravity_turn_start_altitude.
    parameter target_altitude.
    parameter target_inclination.

    local launch_location is ship:geoPosition.
    local launch_azimuth is calculateLaunchAzimuth(target_altitude, target_inclination, launch_location).
    local turn_end_pitch_degrees is 10.
    local turn_end_altitude is 0.
    local turn_exponent is 0.
    local turn_finished is false.
    local steer_to is calculateHeading(90, 90, roll).
    local throttle_to is 1.

    // auto-staging
    local staging_in_progress is false.
    local stage_at_time is time:seconds.
    local stage_separation_delay is 2.

    function isComplete {
        return turn_finished.
    }

    function update {

        // calculate the gravity turn once
        if turn_end_altitude = 0 or turn_exponent = 0 {
            local launch_twr is getThrustForStage() / (ship:mass * ship:body:mu / (altitude + ship:body:radius) ^ 2).
            set turn_end_altitude to (0.128 * ship:body:atm:height * launch_twr) + (0.5 * ship:body:atm:height).
            set turn_exponent to max(1 / (2.5 * launch_twr - 1.7), 0.25).
            debugLog("Pitch program started").
        }

        // check auto-staging
        local flameout is checkEngineFlameOut().
        local no_thrust is ship:maxthrust < 0.01.
        if (flameout or no_thrust) and not staging_in_progress {
            set stage_at_time to time:seconds + stage_separation_delay.
            set staging_in_progress to true.
            debugLog("Staging...").
        }
        if time:seconds >= stage_at_time and staging_in_progress {
            stage.
            set staging_in_progress to false.
        }

        // do not turn if we're about to stage (to prevent spinning while staging)
        if staging_in_progress {
            return.
        }

        // calculate pitch
        local steer_to_pitch is max(90 - (((altitude - gravity_turn_start_altitude) / (turn_end_altitude - gravity_turn_start_altitude)) ^ turn_exponent * 90), turn_end_pitch_degrees).
    
        // calculate heading
        if abs(ship:orbit:inclination - abs(target_inclination)) > 2 {
            set steer_to_direction to launch_azimuth.
        } else if target_inclination >= 0 and vAng(vxcl(ship:up:vector, ship:facing:vector), ship:north:vector) <= 90{
            set steer_to_direction to (90 - target_inclination) - 2 * (abs(target_inclination) - ship:orbit:inclination).
        } else {
            set steer_to_direction to (90 - target_inclination) + 2 * (abs(target_inclination) - ship:orbit:inclination).
        }
        local tmp_heading is calculateHeading(steer_to_direction, steer_to_pitch, roll).

        // limit angle of attack depending on aerodynamic pressure
        // TODO: throttle down at max Q
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
        if (target_altitude - ship:apoapsis) < 5000 {
            set throttle_to to 0.1.
        }

        // throttle off when target apoapsis is reached
        if ship:apoapsis >= target_altitude {
            set throttle_to to 0.
            set turn_finished to true.
            debugLog("Apoapsis reached").
        }
    }

    function getDirection {
        return steer_to.
    }

    function getThrottle {
        return throttle_to.
    }

    function getName {
        return "Gravity turn".
    }

    return lexicon(
        "isComplete", isComplete@,
        "update", update@,
        "getDirection", getDirection@,
        "getThrottle", getThrottle@,
        "getName", getName@
    ).
}
