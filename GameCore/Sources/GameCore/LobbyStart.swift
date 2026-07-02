import Foundation

public extension Lobby {
    /// Deals the first hand only when the lobby is ready to start.
    func startIfReady(seed: UInt64, dealerIndex: Int = 0,
                      turnDuration: TimeInterval = TurnClock.defaultDuration,
                      now: Date = Date()) -> GameState? {
        guard canStart else { return nil }
        return start(seed: seed, dealerIndex: dealerIndex,
                     turnDuration: turnDuration, now: now)
    }

    /// Deals the first hand from the lobby's seats, each with the starting stack.
    func start(seed: UInt64, dealerIndex: Int = 0,
               turnDuration: TimeInterval = TurnClock.defaultDuration,
               now: Date = Date()) -> GameState {
        let players = seats.map {
            Player(id: $0.id, name: $0.name, avatar: $0.avatar, stack: startingStack)
        }
        return GameState.startHand(players: players, dealerIndex: dealerIndex,
                                   smallBlind: smallBlind, bigBlind: bigBlind,
                                   seed: seed, handNumber: 1, tableID: tableID,
                                   appliedOperationIDs: appliedOperationIDs,
                                   turnDuration: turnDuration,
                                   now: now)
    }
}
