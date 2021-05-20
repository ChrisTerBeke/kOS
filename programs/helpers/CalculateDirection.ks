function calculateDirection {
    parameter target_inclination.
    parameter launch_azimuth.

    if abs(ship:orbit:inclination - abs(target_inclination)) > 2 {
        return launch_azimuth.
    } else if target_inclination >= 0 and vAng(vxcl(ship:up:vector, ship:facing:vector), ship:north:vector) <= 90 {
        return (90 - target_inclination) - 2 * (abs(target_inclination) - ship:orbit:inclination).
    } else {
        return (90 - target_inclination) + 2 * (abs(target_inclination) - ship:orbit:inclination).
    }
}
