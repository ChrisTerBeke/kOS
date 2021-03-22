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

    return lexicon(
        "update", update@,
        "setEnabled", setEnabled@,
        "enterPressed", enterPressed@
    ).
}
