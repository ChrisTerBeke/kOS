function calculateHeading {
    parameter inputHeading, inputPitch, inputRoll.
    local return_direction is heading(inputHeading, inputPitch).
    return angleAxis(inputRoll, return_direction:forevector) * return_direction.
}
