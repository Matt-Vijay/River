import Foundation

extension GameState {
    /// Deals the next hand from this table, preserving chip stacks and advancing
    /// the button in the original table order before left or busted seats are
    /// removed.
    public func startNextHand(seed: UInt64, now: Date = Date()) -> GameState? {
        guard isHandComplete else { return nil }
        let eligibleOriginalIndices = eligibleOriginalSeatIndicesForNextHand()
        guard eligibleOriginalIndices.count >= 2 else { return nil }

        let nextDealerOriginalIndex = nextOriginalSeatAfterDealer(in: Set(eligibleOriginalIndices))
        let nextPlayers = eligibleOriginalIndices.map { players[$0] }
        guard let dealer = eligibleOriginalIndices.firstIndex(of: nextDealerOriginalIndex) else {
            return nil
        }

        var next = GameState.startHand(
            players: nextPlayers,
            dealerIndex: dealer,
            smallBlind: smallBlind,
            bigBlind: bigBlind,
            seed: seed,
            handNumber: handNumber + 1,
            tableID: tableID,
            appliedOperationIDs: appliedOperationIDs,
            turnDuration: turnDuration,
            now: now
        )
        next.version = version + 1
        return next
    }

    private func nextOriginalSeatAfterDealer(in eligible: Set<Int>) -> Int {
        guard !players.isEmpty else { return dealerIndex }
        let dealerIndex = Self.normalizedSeat(dealerIndex, playerCount: players.count)
        for offset in 1...players.count {
            let candidate = (dealerIndex + offset) % players.count
            if eligible.contains(candidate) { return candidate }
        }
        return eligible.min() ?? dealerIndex
    }
}
