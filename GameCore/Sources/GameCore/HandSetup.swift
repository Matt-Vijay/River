extension GameState {
    static func preparedPlayersForNewHand(_ input: [Player]) -> [Player] {
        var players = input
        for i in players.indices {
            players[i].bet = 0
            players[i].committed = 0
            players[i].holeCards = []
            players[i].hasActed = false
            players[i].lastAction = nil
            players[i].status = statusForFreshHand(players[i])
        }
        return players
    }

    func eligibleOriginalSeatIndicesForNextHand() -> [Int] {
        players.indices.filter { players[$0].canEnterNextHand }
    }

    private static func statusForFreshHand(_ player: Player) -> PlayerStatus {
        if player.canEnterNextHand { return .active }
        return player.hasLeft ? .sittingOut : .eliminated
    }

    static func dealOrder(players: [Player], dealerIndex: Int) -> [Int] {
        guard !players.isEmpty else { return [] }

        var order: [Int] = []
        var seat = dealerIndex
        for _ in 0..<players.count {
            seat = (seat + 1) % players.count
            if players[seat].status == .active { order.append(seat) }
        }
        return order
    }

    static func dealHoleCards(to players: inout [Player], deck: inout [Card], dealOrder: [Int]) {
        for _ in 0..<2 {
            for seatIndex in dealOrder {
                guard let card = deck.dealTopIfAvailable() else { return }
                players[seatIndex].holeCards.append(card)
            }
        }
    }
}
