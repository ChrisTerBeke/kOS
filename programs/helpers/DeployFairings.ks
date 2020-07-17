// deploy all fairings
// TODO: filter out fairings we want to keep attached
function deployFairings {
    for fairing in ship:modulesNamed("ModuleProceduralFairing") {
        fairing:doEvent("deploy").
    }
}
