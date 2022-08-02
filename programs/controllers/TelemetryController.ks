function TelemetryController {

    parameter mission_name.

    local is_enabled is false.
    local telemetry_top_row is 0.
	local telemetry is lexicon().

    // TODO: queue telemetry locally and copy to archive periodically to simulate data downlink
    local archive_volume is volume(0).
    switch to archive_volume.
    local file_name is "logs/telemetry/" + mission_name + "/" + time:seconds + ".csv".
    archive_volume:create(file_name).
    local telemetry_downlink is archive_volume:open(file_name).
    local telemetry_downlink_write_header is true.

    function update {
        if not is_enabled {
            return.
        }
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

	function setTelemetry {
		parameter telemetry_lex.
		set telemetry to telemetry_lex.
	}

    function _printTelemetry {
        local telemetry_iterator is telemetry:keys:iterator.
        until not telemetry_iterator:next {
            local index is telemetry_iterator:index.
            local key is telemetry_iterator:value.
            local value is telemetry[key].
            _printTelemetryLine(key + ": " + value, telemetry_top_row + index).
        }
    }

    function _printTelemetryLine {
        parameter text.
        parameter line_number.
        print "                                                                             " at (0, line_number).
        print text at (0, line_number).
    }

    function _logTelemetry {

        // CSV header
        if telemetry_downlink_write_header = true {
            local telemetry_header is telemetry:keys:join(",").
            telemetry_downlink:writeln(telemetry_header).
            set telemetry_downlink_write_header to false.
        }

        local telemetry_line is telemetry:values:join(",").
        telemetry_downlink:writeln(telemetry_line).
    }

    return lexicon(
        "update", update@,
        "setEnabled", setEnabled@,
		"setTelemetry", setTelemetry@
    ).
}
