extension GameState {
    struct SidePot {
        var amount: Int
        var eligible: [Int]
    }

    func buildSidePots() -> [SidePot] {
        let levels = Set(players.map(\.committed).filter { $0 > 0 }).sorted()
        var pots: [SidePot] = []
        var previous = 0
        for level in levels {
            let contributors = players.indices.filter { players[$0].committed >= level }
            let amount = (level - previous) * contributors.count
            let eligible = contributors.filter { players[$0].isContesting }
            pots.append(SidePot(amount: amount, eligible: eligible))
            previous = level
        }
        return pots
    }
}
