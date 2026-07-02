extension GameState {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: GameStateCodingKeys.self)
        try container.encode(tableID, forKey: .tableID)
        try container.encode(appliedOperationIDs, forKey: .appliedOperationIDs)
        try container.encode(handNumber, forKey: .handNumber)
        try container.encode(players, forKey: .players)
        try container.encode(dealerIndex, forKey: .dealerIndex)
        try container.encode(smallBlind, forKey: .smallBlind)
        try container.encode(bigBlind, forKey: .bigBlind)
        try container.encode(board, forKey: .board)
        try container.encode(deck, forKey: .deck)
        try container.encode(pot, forKey: .pot)
        try container.encode(street, forKey: .street)
        try container.encodeIfPresent(currentToAct, forKey: .currentToAct)
        try container.encode(currentBet, forKey: .currentBet)
        try container.encode(minRaise, forKey: .minRaise)
        try container.encodeIfPresent(turnStartedAt, forKey: .turnStartedAt)
        try container.encode(turnDuration, forKey: .turnDuration)
        try container.encodeIfPresent(results, forKey: .results)
        try container.encode(version, forKey: .version)
    }
}
