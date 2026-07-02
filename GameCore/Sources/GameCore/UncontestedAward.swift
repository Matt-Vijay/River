extension GameState {
    mutating func awardUncontested() {
        collectBets()
        guard let winner = players.indices.first(where: { players[$0].isContesting }) else { return }
        let amount = pot
        players[winner].stack += amount
        results = [HandResult(playerID: players[winner].id, amountWon: amount, handName: nil, bestFive: nil)]
        pot = 0
        currentToAct = nil
        street = .showdown
        turnStartedAt = nil
    }
}
