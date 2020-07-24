// controller responsibe for vehicle steering
function SteeringController {

    local is_enabled is false.
	local steer_to is up.

	// TODO: is this still needed?
    // set steeringManager:rollpid:ki to 0.
    // set steeringManager:rollpid:kp to 0.

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
        parameter new_direction.
        set steer_to to new_direction.
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
