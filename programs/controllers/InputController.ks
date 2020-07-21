function InputController {

    local is_enabled is false.

    function update {
        if not is_enabled {
            return.
        }
    }

    function enterPressed {
        if terminal:input:haschar {
            local input is terminal:input:getchar().
            if input = terminal:input:enter {
                return true.
            }
        }
        return false.
    }

    function setEnabled {
        parameter value.
		if is_enabled = value {
			return.
		}
        set is_enabled to value.
    }

    function getMissionProfile {
        parameter mission_profile_file_name.
        // TODO: write custom de-serializer to improve configuration file readibility
        local mission_profile is readJson("0:/programs/missions/" + mission_profile_file_name).
        return mission_profile.
    }

    return lexicon(
        "update", update@,
        "setEnabled", setEnabled@,
        "getMissionProfile", getMissionProfile@,
        "enterPressed", enterPressed@
    ).
}
