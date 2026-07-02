import Foundation
import GameCore

struct MessageTableSettings {
    var maxPlayers = Lobby.defaultMaxPlayers
    var startingStack = Lobby.defaultStartingStack
    var smallBlind = Lobby.defaultSmallBlind
    var bigBlind = Lobby.defaultBigBlind
    var turnDuration: TimeInterval = TurnClock.defaultDuration

    func makeLobby() -> Lobby {
        Lobby(maxPlayers: maxPlayers,
              smallBlind: smallBlind,
              bigBlind: bigBlind,
              startingStack: startingStack)
    }
}
