public extension GameState {
    var dealerSeatIndex: Int? {
        guard !players.isEmpty else { return nil }
        return Self.normalizedSeat(dealerIndex, playerCount: players.count)
    }

    func isDealer(at index: Int) -> Bool {
        dealerSeatIndex == index && players.indices.contains(index)
    }

    var firstActorAfterDealer: Int? {
        guard let dealerSeatIndex else { return nil }
        return nextSeat(after: dealerSeatIndex) { $0.canAct }
    }

    static func normalizedSeat(_ index: Int, playerCount: Int) -> Int {
        guard playerCount > 0 else { return 0 }
        return ((index % playerCount) + playerCount) % playerCount
    }
}
