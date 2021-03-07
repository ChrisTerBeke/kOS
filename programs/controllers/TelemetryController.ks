function TelemetryController {

    parameter mission_name.

    local is_enabled is false.
    local message_list_top_row is 0.
    local max_messages_on_screen is 5.
    local telemetry_top_row is max_messages_on_screen + 1.
	local telemetry is lexicon().
    local message_list is list().

    // TODO: queue telemetry locally and copy to archive periodically to simulate data downlink
    local archive_volume is volume(0).
    switch to archive_volume.
    local file_name is "logs/telemetry/" + mission_name + "/" + time:seconds + ".csv".
    archive_volume:create(file_name).
    local telemetry_downlink is archive_volume:open(file_name).

    function update {
        if not is_enabled {
            return.
        }
        _printMessages().
        _printTelemetry().
        _logTelemetry().
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

	function setTelemetry {
		parameter telemetry_lex.
		set telemetry to telemetry_lex.
	}

    function _printMessages {
        from { local m is 0. } until m = max_messages_on_screen step { set m to m + 1. } do {
            local message_index is message_list:length - 1 - m.
            if message_index > -1 and message_list:length > message_index {
                _printTelemetryLine(message_list[message_index], message_list_top_row + m).
            }
        }
    }

    function _printTelemetry {
        // print all telemetry items
        // we use an iterator so we can calculate the correct row to print on
        local telemetry_iterator is telemetry:keys:iterator.
        until not telemetry_iterator:next {
            local index is telemetry_iterator:index.
            local key is telemetry_iterator:value.
            local value is telemetry[key].
            _printTelemetryLine(key + ": " + value, telemetry_top_row + index).
            log key + ": " + value to "telemetry.csv".
        }
    }

    function _printTelemetryLine {
        parameter text.
        parameter line_number.
        print "                                                                             " at (0, line_number).
        print text at (0, line_number).
    }

    function _logTelemetry {
        local telemetry_line is telemetry:values:join(",").
        telemetry_downlink:writeln(telemetry_line).
    }

    return lexicon(
        "update", update@,
        "setEnabled", setEnabled@,
        "addMessage", addMessage@,
        "addMessages", addMessages@,
		"setTelemetry", setTelemetry@
    ).
}
