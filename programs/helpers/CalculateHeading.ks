function calculateHeading {
    parameter input_direction, input_pitch, input_roll.
    return heading(input_direction, input_pitch) + r(0, 0, input_roll).
}
