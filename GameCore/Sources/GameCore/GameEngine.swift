import Foundation

extension GameState {
    /// Returns a copy of the state with the action applied.
    public func applying(_ action: PlayerAction, by index: Int, now: Date = Date()) -> GameState {
        var copy = self
        copy.apply(action, by: index, now: now)
        return copy
    }

    @discardableResult
    public mutating func apply(_ action: PlayerAction, by index: Int, now: Date = Date()) -> Bool {
        guard players.indices.contains(index) else { return false }
        guard isCurrentPlayer(at: index), players[index].canAct else { return false }
        guard legalActions(for: index).allows(action) else { return false }

        switch action {
        case .fold:
            foldPlayer(at: index)

        case .check:
            checkPlayer(at: index)

        case .call:
            callPlayer(at: index)

        case .raise(let to):
            guard raisePlayer(at: index, to: to) else { return false }
        }

        version += 1
        advance(now: now)
        return true
    }
}
