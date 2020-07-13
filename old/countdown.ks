// generic countdown script
declare local parameter countdown_from is 10.
from {
    local count is countdown_from.
} until count = 0 step {
    set count to count - 1.
} do {
    print count + "...".
    wait 1.
}
