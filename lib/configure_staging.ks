// staging logic
declare local parameter stop_at_stage is 0.

// auto stage
when maxThrust = 0 and stage:liquidfuel < 0.1 then {
    print "stage separation".
    stage.
    wait 1.
    return stage:number > stop_at_stage.
}

// drop solid rocket boosters (once)
when stage:solidfuel < 0.1 then {
    print "srb separation".
    stage.
}
