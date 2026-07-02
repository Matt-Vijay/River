public extension GameState {
    /// Total chips in the middle, including the live betting round.
    var displayPot: Int {
        pot + players.reduce(0) { $0 + $1.bet }
    }

    /// Players still contesting the pot.
    var contenders: [Player] {
        players.filter(\.isContesting)
    }

    /// Players still at the table and holding chips.
    var presentPlayers: [Player] {
        players.filter { !$0.hasLeft && $0.stack > 0 }
    }

    /// Players who can be dealt into the next hand.
    var fundedPlayerCount: Int { presentPlayers.count }

    /// Whether the current hand has produced a terminal result.
    var isHandComplete: Bool { results != nil }

    /// The single remaining player, if the game is over.
    var overallWinner: Player? {
        guard isHandComplete else { return nil }
        return presentPlayers.count == 1 ? presentPlayers.first : nil
    }

    /// Whether the table has a single remaining funded player and no more hands can be dealt.
    var isGameOver: Bool {
        overallWinner != nil
    }

    /// Whether this participant is allowed to advance a completed table to the next hand.
    func canDealNextHand(actorID: String) -> Bool {
        guard isHandComplete, !isGameOver else { return false }
        guard let player = player(id: actorID) else { return false }
        return !player.hasLeft && player.stack > 0
    }
}
