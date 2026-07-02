extension GameState {
    /// Next seat after `index` (wrapping) satisfying `predicate`.
    func nextSeat(after index: Int, where predicate: (Player) -> Bool) -> Int? {
        let n = players.count
        guard n > 0 else { return nil }
        let start = Self.normalizedSeat(index, playerCount: n)
        for offset in 1...n {
            let j = (start + offset) % n
            if predicate(players[j]) { return j }
        }
        return nil
    }
}
