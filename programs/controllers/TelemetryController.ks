function TelemetryController {

    local is_enabled is false.
    local message_list_top_row is 0.
    local max_messages_on_screen is 5.
    local telemetry_top_row is max_messages_on_screen + 1.
	local custom_telemetry is lexicon().
    local message_list is list().

    function update {
        if not is_enabled {
            return.
        }
        _printMessages().
        _printTelementry().
    }

    function setEnabled {
        parameter value.
		if is_enabled = value {
			return.
		}
        set is_enabled to value.
    }

    function addMessage {
        parameter message.
        message_list:add(message).
    }

    function addMessages {
        parameter messages.
        for message in messages {
            message_list:add(message).
        }
    }

	function setCustomTelemetry {
		parameter telemetry_lex.
		set custom_telemetry to telemetry_lex.
	}

    function _printMessages {
        from { local m is 0. } until m = max_messages_on_screen step { set m to m + 1. } do {
            local message_index is message_list:length - 1 - m.
            if message_index > -1 and message_list:length > message_index {
                print "                                                                             " at (0, message_list_top_row + m).
                print message_list[message_index] at (0, message_list_top_row + m).
            }
        }
    }

    function _printTelementry {
        print "Altitude: " + ship:altitude at(0, telemetry_top_row).
        print "Apoapsis: " + ship:orbit:apoapsis at(0, telemetry_top_row + 1).
        print "  ETA: " + eta:apoapsis at (0, telemetry_top_row + 2).
        print "Periapsis: " + ship:orbit:periapsis at (0, telemetry_top_row + 3).
        print "  ETA: " + eta:periapsis at (0, telemetry_top_row + 4).
        print "Eccentricity: " + ship:orbit:eccentricity at (0, telemetry_top_row + 5).
        print "Inclination: " + ship:orbit:inclination at (0, telemetry_top_row + 6).
        print "Pitch: " + (90 - vectorAngle(up:forevector, facing:forevector)) at (0, telemetry_top_row + 7).

		// print the custom telemetry items
		// we use an iterator on the lexicon key so we can calculate the correct row to print on
		local custom_telemetry_iter is custom_telemetry:keys:iterator.
		until not custom_telemetry_iter:next {
			local index is custom_telemetry_iter:index.
			local key is custom_telemetry_iter:value.
			print key + ": " + custom_telemetry[key] at (0, telemetry_top_row + 8 + index).
		}
    }

    return lexicon(
        "update", update@,
        "setEnabled", setEnabled@,
        "addMessage", addMessage@,
        "addMessages", addMessages@,
		"setCustomTelemetry", setCustomTelemetry@
    ).
}
