extension GameState {
    func rankedContenders(in sidePot: SidePot, ranks: [Int: HandRank]) -> [(index: Int, rank: HandRank)] {
        sidePot.eligible.compactMap { index in
            guard players[index].isContesting, let rank = ranks[index] else { return nil }
            return (index, rank)
        }
    }

    /// Seat distance from the dealer (0 = first left of dealer), for odd-chip order.
    func seatOrder(_ index: Int) -> Int {
        let n = players.count
        guard let dealerSeatIndex else { return 0 }
        return Self.normalizedSeat(index - dealerSeatIndex - 1, playerCount: n)
    }
}
