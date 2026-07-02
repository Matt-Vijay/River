import Foundation
import GameCore

struct TableActionEntropy {
    var makeSeed: () -> UInt64

    static let live = TableActionEntropy {
        UInt64.random(in: .min ... .max)
    }
}

struct TableMessageActions {
    var settings: MessageTableSettings
    var entropy: TableActionEntropy = .live

    func newLobby(heroID: String, name: String, avatar: String) -> TableMessage {
        .lobby(settings.makeLobby().adding(id: heroID, name: name, avatar: avatar))
    }

    func joinLobby(name: String, avatar: String) -> TableOperation.Kind {
        .joinLobby(name: name, avatar: avatar)
    }

    func toggleReady(in lobby: Lobby, heroID: String) -> TableOperation.Kind {
        return .setReady(isReady: !lobby.isReady(id: heroID),
                         startSeed: entropy.makeSeed(),
                         turnDuration: settings.turnDuration)
    }

    func gameAction(_ action: PlayerAction) -> TableOperation.Kind {
        .gameAction(action)
    }

    func joinGame(name: String, avatar: String) -> TableOperation.Kind {
        .joinGame(name: name, avatar: avatar, startingStack: settings.startingStack)
    }

    func leaveGame() -> TableOperation.Kind {
        .leaveGame
    }

    func leaveLobby() -> TableOperation.Kind {
        .leaveLobby
    }

    func dealNextHand() -> TableOperation.Kind {
        .dealNextHand(seed: entropy.makeSeed())
    }
}
