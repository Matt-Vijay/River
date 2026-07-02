import Foundation

extension GameState {
    /// A player leaves the table and is excluded from future deals. During a
    /// live hand they forfeit by folding; after results exist the completed hand
    /// is left intact.
    @discardableResult
    public mutating func playerLeaves(id: String, now: Date = Date()) -> Bool {
        guard !isGameOver else { return false }
        guard let idx = playerIndex(id: id), !players[idx].hasLeft else { return false }
        players[idx].hasLeft = true
        version += 1
        guard !isHandComplete else { return true }
        guard players[idx].isContesting else { return true }

        players[idx].status = .folded
        players[idx].hasActed = true
        players[idx].lastAction = .fold

        if isCurrentPlayer(at: idx) {
            advance(now: now)
        } else if contenders.count <= 1 {
            awardUncontested()
        }
        return true
    }
}
