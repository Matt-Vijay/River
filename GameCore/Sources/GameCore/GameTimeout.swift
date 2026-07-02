import Foundation

extension GameState {
    /// If the current player has exceeded the turn clock, resolve their turn as
    /// a check (if free) or fold, and advance. Called by the next acting client
    /// before it decides whose turn it is. Resolves at most one stale turn; the
    /// new current player gets a fresh clock from `now`.
    @discardableResult
    public mutating func resolveTimeout(now: Date = Date()) -> Bool {
        guard let index = currentToAct, let started = turnStartedAt else { return false }
        guard players.indices.contains(index) else { return false }
        guard now.timeIntervalSince(started) >= turnDuration else { return false }
        let legal = legalActions(for: index)
        return apply(legal.canCheck ? .check : .fold, by: index, now: now)
    }
}
