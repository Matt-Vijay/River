import SwiftUI
import GameCore

public struct GameControllerEnvironment: Sendable {
    public var makeSeed: @Sendable () -> UInt64
    public var now: @Sendable () -> Date

    public init(makeSeed: @escaping @Sendable () -> UInt64,
                now: @escaping @Sendable () -> Date) {
        self.makeSeed = makeSeed
        self.now = now
    }

    public static let live = GameControllerEnvironment(
        makeSeed: { UInt64.random(in: .min ... .max) },
        now: Date.init
    )
}

/// Drives a local **pass-and-play** game (no bots): whoever's turn it is becomes
/// the "hero" on screen, so a real person makes every decision and passes the
/// device around the table. Shared by the macOS harness and the iOS demo app.
@MainActor
@Observable
public final class GameController {
    public private(set) var state: GameState

    private let environment: GameControllerEnvironment

    /// Starts a game from a finished lobby (the real entry point).
    public init(lobby: Lobby, environment: GameControllerEnvironment = .live) {
        self.environment = environment
        state = lobby.start(seed: environment.makeSeed(), now: environment.now())
    }

    /// The current actor is shown as the hero (pass-and-play); falls back to the
    /// first player between hands.
    public var heroID: String {
        if let currentPlayer = state.currentPlayer { return currentPlayer.id }
        return state.players.first?.id ?? ""
    }

    public var handOver: Bool { state.isHandComplete }

    public func act(_ action: PlayerAction) {
        guard let i = state.currentToAct else { return }
        withAnimation(.tableSnap) {
            _ = state.apply(action, by: i, now: environment.now())
        }
    }

    /// A player leaves the table (forfeits the hand, excluded next deal).
    public func leave(id: String) {
        withAnimation(.tableSnap) {
            _ = state.playerLeaves(id: id, now: environment.now())
        }
    }

    public func dealNextHand() {
        guard let next = state.startNextHand(seed: environment.makeSeed(), now: environment.now()) else { return }
        withAnimation(.tableSnap) {
            state = next
        }
    }
}
