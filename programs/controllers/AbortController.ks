function AbortController {

    local is_enabled is false.
    local should_abort is false.
    local enable_abort_detection is true.
    local abort_on_loss_off_control is false.
    local abort_on_insufficient_thrust is false.

    function update {
        if not is_enabled {
            return.
        }
        _checkAbort().
        _abort().
    }

    function setEnabled {
        parameter value.
		if is_enabled = value {
			return.
		}
        set is_enabled to value.
    }

    function doAbort {
        set should_abort to true.
    }

    function setAbortOnLossOfControl {
        parameter value.
        set abort_on_loss_off_control to value.
    }

    function setAbortOnInsufficientThrust {
        parameter value.
        set abort_on_insufficient_thrust to value.
    }

    function _abort {
        if should_abort {
            set ship:control:neutralize to true.
            unlock steering.
            unlock throttle.
            sas on.
            abort on.
        }
    }

    function _checkAbort {
        local loss_off_control is abort_on_loss_off_control and vAng(ship:facing:vector, steering:vector) > 45.
        local insufficient_thrust is abort_on_insufficient_thrust and verticalSpeed < -1.0.
        if (loss_off_control or insufficient_thrust) and enable_abort_detection {
            set should_abort to true.
        }
    }

    return lexicon(
        "doAbort", doAbort@,
        "update", update@,
        "setEnabled", setEnabled@,
        "setAbortOnLossOfControl", setAbortOnLossOfControl@,
        "setAbortOnInsufficientThrust", setAbortOnInsufficientThrust@
    ).
}
