import Foundation

/// What a conversation's message carries: either the lobby (pre-game) or a live
/// game state. The whole thing travels in the `MSMessage.url`.
public enum TableMessage: Codable, Sendable, Equatable {
    case lobby(Lobby)
    case game(GameState)
}

public extension TableMessage {
    var revision: TableRevision {
        switch self {
        case .lobby(let lobby):
            return TableRevision(tableID: lobby.tableID, phase: .lobby, version: lobby.version)
        case .game(let state):
            return TableRevision(tableID: state.tableID, phase: .game, version: state.version)
        }
    }
}
