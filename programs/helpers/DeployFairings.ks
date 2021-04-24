// deploy all fairings
function deployFairings {
    for fairing in ship:modulesNamed("ModuleProceduralFairing") {
        if fairing:hasEvent("deploy") {
            fairing:doEvent("deploy").
        }
    }
}
