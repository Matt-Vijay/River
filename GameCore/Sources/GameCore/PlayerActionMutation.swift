extension GameState {
    mutating func foldPlayer(at index: Int) {
        players[index].status = .folded
        players[index].hasActed = true
        players[index].lastAction = .fold
    }

    mutating func checkPlayer(at index: Int) {
        players[index].hasActed = true
        players[index].lastAction = .check
    }

    mutating func callPlayer(at index: Int) {
        let toCall = min(currentBet - players[index].bet, players[index].stack)
        pay(index, additional: toCall)
        players[index].hasActed = true
        players[index].lastAction = .call
    }
}
