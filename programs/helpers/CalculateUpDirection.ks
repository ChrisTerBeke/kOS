runOncePath("programs/helpers/CalculateHeading").  // #include "./CalculateHeading.ks"

function calculateUpDirection {
    return calculateHeading(90, 90, ship:facing:roll + vectorangle(up:vector, ship:facing:starvector)).
}
