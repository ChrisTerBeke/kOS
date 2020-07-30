runOncePath("programs/helpers/CheckEngineFlameOut"). // #include "../helpers/CheckEngineFlameOut.ks"

function StagingController {

    local is_enabled is false.
    local message_list is list().
    local auto_detect_staging is false.
    local should_stage is false.
    local staging_in_progress is false.
    local stage_at_time is time:seconds.
    local stage_separation_delay is 2.

    function update {
        if not is_enabled {
            return.
        }
        _checkStaging().
    }

    function setEnabled {
        parameter value.
		if is_enabled = value {
			return.
		}
        set is_enabled to value.
    }

    function doStage {
        set should_stage to true.
    }

    function doAbort {
        set should_stage to false.
        set staging_in_progress to false.
    }

    function setAutoDetectStaging {
        parameter value.
        set auto_detect_staging to value.
    }

    function setForceStaging {
        parameter value.
        set should_stage to value.
    }

    function getMessages {
        local messages is message_list:copy().
        message_list:clear().
        return messages.
    }

    function _checkStaging {
        local flameout is checkEngineFlameOut() and auto_detect_staging.
        local no_thrust is ship:maxthrust < 0.01 and auto_detect_staging.
        if (flameout or no_thrust or should_stage) and not staging_in_progress {
            set should_stage to false.
            set stage_at_time to time:seconds + stage_separation_delay.
            set staging_in_progress to true.
            _logWithT("Stage separation in progress.").
        }
        if time:seconds >= stage_at_time and staging_in_progress {
            stage.
            set staging_in_progress to false.
            _logWithT("Stage separation confirmed.").
        }
    }

    function _logWithT {
        local parameter text.
        local line is "T+" + round(missionTime, 2) + ": " + text.
        message_list:add(line).
    }

    return lexicon(
        "update", update@,
        "setEnabled", setEnabled@,
        "doStage", doStage@,
        "doAbort", doAbort@,
        "setAutoDetectStaging", setAutoDetectStaging@,
        "setForceStaging", setForceStaging@,
        "getMessages", getMessages@
    ).
}
