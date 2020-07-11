// auto staging logic
declare local parameter max_stage is 0.

// separate states until given max stage
when maxThrust = 0 and stage:number < max_stage then {
    print "stage separation".
    stage.
    wait 1.
    preserve.
}

// separate solid rocket boosters
// TODO: fix this
// when stage:solidfuel < 1 and stage:nextDecoupler:name = "radialDecoupler1-2" then {
//     print "booster separation".
//     stage.
// }
