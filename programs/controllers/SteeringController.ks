// controller responsibe for vehicle steering
function SteeringController {

    local is_enabled is false.
	local steer_to is up.

    function update {
        if not is_enabled {
            return.
        }

        // turn on RCS when in space
        if altitude > ship:body:atm:height {
            rcs on.
        } else {
            rcs off.
        }
    }

    function setEnabled {
        parameter value.
		if is_enabled = value {
			return.
		} else if value = true {
            sas off.
            lock steering to steer_to.
        } else {
            unlock steering.
            sas on.
        }
        set is_enabled to value.
    }

    function setDirection {
        parameter new_direction.
        set steer_to to new_direction.
    }

	function doAbort {
        setEnabled(false).
	}

    return lexicon(
        "update", update@,
        "setEnabled", setEnabled@,
        "setDirection", setDirection@,
		"doAbort", doAbort@
    ).
}
