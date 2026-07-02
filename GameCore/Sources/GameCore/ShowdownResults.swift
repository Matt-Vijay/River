extension GameState {
    func showdownRanks() -> [Int: HandRank] {
        var ranks: [Int: HandRank] = [:]
        for index in players.indices where players[index].isContesting {
            ranks[index] = HandEvaluator.evaluateIfPossible(players[index].holeCards + board)
        }
        return ranks
    }

    func showdownResults(ranks: [Int: HandRank], winnings: [String: Int]) -> [HandResult] {
        players.indices.compactMap { index in
            guard players[index].isContesting else { return nil }
            return HandResult(
                playerID: players[index].id,
                amountWon: winnings[players[index].id] ?? 0,
                handName: ranks[index]?.name,
                bestFive: ranks[index]?.bestFive
            )
        }
    }
}
