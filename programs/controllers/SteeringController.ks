// controller responsibe for vehicle steering
function SteeringController {

    local is_enabled is false.
	local steer_to is up.

	// TODO: figure out why heading:roll does not work properly
    set steeringManager:rollpid:ki to 0.
    set steeringManager:rollpid:kp to 0.

    function update {
        if not is_enabled {
            return.
        }
    }

    function setEnabled {
        parameter value.
		if is_enabled = value {
			return.
		} else if value = true {
            lock steering to steer_to.
        } else {
            unlock steering.
        }
        set is_enabled to value.
    }

    function setDirection {
        parameter direction.
        set steer_to to direction.
    }

	function doAbort {
		set is_enabled to false.
	}

    return lexicon(
        "update", update@,
        "setEnabled", setEnabled@,
        "setDirection", setDirection@,
		"doAbort", doAbort@
    ).
}
