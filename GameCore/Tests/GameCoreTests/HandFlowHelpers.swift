import GameCore

/// Plays the hand out with every decision being check-if-free else call,
/// driving it to showdown.
func checkOrCallToShowdown(_ state: inout GameState) {
    var guardCount = 0
    while let index = state.currentToAct, guardCount < 200 {
        let legal = state.legalActions(for: index)
        state.apply(legal.canCheck ? .check : .call, by: index)
        guardCount += 1
    }
}

func totalChips(_ state: GameState) -> Int {
    state.players.reduce(0) { $0 + $1.stack } + state.pot + state.players.reduce(0) { $0 + $1.bet }
}
