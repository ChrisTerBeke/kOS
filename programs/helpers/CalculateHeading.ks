function calculateHeading {
    parameter input_heading, input_pitch, input_roll.
    return heading(input_heading, input_pitch) + r(0, 0, input_roll).
}
