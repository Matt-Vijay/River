extension GameState {
    mutating func award(_ sidePot: SidePot, ranks: [Int: HandRank],
                        winnings: inout [String: Int]) {
        let eligible = rankedContenders(in: sidePot, ranks: ranks)
        guard let best = eligible.map(\.rank).max() else { return }

        let winners = eligible.filter { $0.rank == best }.map(\.index)
        let share = sidePot.amount / winners.count
        var remainder = sidePot.amount % winners.count

        for winner in winners.sorted(by: oddChipPriority) {
            var amount = share
            if remainder > 0 {
                amount += 1
                remainder -= 1
            }
            winnings[players[winner].id, default: 0] += amount
            players[winner].stack += amount
        }
    }

    private func oddChipPriority(_ lhs: Int, _ rhs: Int) -> Bool {
        seatOrder(lhs) < seatOrder(rhs)
    }
}
