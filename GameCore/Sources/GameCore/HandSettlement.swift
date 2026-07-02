extension GameState {

    // MARK: - Resolving the hand

    mutating func collectBets() {
        for i in players.indices {
            pot += max(0, players[i].bet)
            players[i].bet = 0
            players[i].hasActed = false
        }
        currentBet = 0
        minRaise = bigBlind
    }

    mutating func runOutAndShowdown() {
        while board.count < 5 {
            guard let card = deck.dealTopIfAvailable() else { break }
            board.append(card)
        }
        goToShowdown()
    }

    mutating func goToShowdown() {
        street = .showdown
        currentToAct = nil
        turnStartedAt = nil

        let pots = buildSidePots()
        var winnings: [String: Int] = [:]
        let ranks = showdownRanks()

        for sidePot in pots {
            award(sidePot, ranks: ranks, winnings: &winnings)
        }

        results = showdownResults(ranks: ranks, winnings: winnings)
        pot = 0
    }
}
