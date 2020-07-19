// controller responsibe for vehicle throttling
function ThrottleController {

    local is_enabled is false.
	local throttle_to is 0.

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
            lock throttle to throttle_to.
			set ship:control:pilotmainthrottle to 0.
        } else {
            unlock throttle.
			set ship:control:pilotmainthrottle to 1.
        }
        set is_enabled to value.
    }

    function setThrottle {
        parameter throttle_amount.
        set throttle_to to throttle_amount.
    }

	function doAbort {
		set is_enabled to false.
	}

    return lexicon(
        "update", update@,
        "setEnabled", setEnabled@,
        "setThrottle", setThrottle@,
		"doAbort", doAbort@
    ).
}
