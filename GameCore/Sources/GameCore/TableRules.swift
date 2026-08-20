enum TableRules {
    static let minPlayers = 2
    static let maxPlayers = 6
    static let defaultStartingStack = 1000
    static let buyInMaximum = Int.max / (maxPlayers + 1)
    static let tableMaximum = buyInMaximum * maxPlayers

    static func normalizedMaxPlayers(_ value: Int) -> Int {
        min(max(value, minPlayers), maxPlayers)
    }

    static func normalizedStartingStack(_ value: Int) -> Int {
        value > 0 ? min(value, buyInMaximum) : defaultStartingStack
    }

    static func table(_ value: Int) -> Int {
        min(max(0, value), tableMaximum)
    }

    static func adding(_ lhs: Int, _ rhs: Int, limit: Int) -> Int {
        let lhs = min(max(0, lhs), limit)
        let rhs = min(max(0, rhs), limit)
        guard lhs <= limit - rhs else { return limit }
        return lhs + rhs
    }

    static func normalizedBlinds(smallBlind: Int, bigBlind: Int) -> (
        smallBlind: Int,
        bigBlind: Int
    ) {
        let smallBlind = min(max(1, smallBlind), buyInMaximum / 2)
        return (
            smallBlind,
            min(max(smallBlind * 2, bigBlind), buyInMaximum)
        )
    }
}
