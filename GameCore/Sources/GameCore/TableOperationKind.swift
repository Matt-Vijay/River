import Foundation

public extension TableOperation {
    enum Kind: Codable, Sendable, Equatable {
        case joinLobby(name: String, avatar: String)
        case updateLobbyProfile(name: String? = nil, avatar: String? = nil)
        case setReady(isReady: Bool, name: String? = nil, avatar: String? = nil, startSeed: UInt64, turnDuration: TimeInterval)
        case leaveLobby
        case gameAction(PlayerAction)
        case joinGame(name: String, avatar: String, startingStack: Int)
        case leaveGame
        case dealNextHand(seed: UInt64, name: String? = nil, avatar: String? = nil)
    }
}

extension TableOperation.Kind {
    var normalized: Self {
        switch self {
        case .joinLobby(let name, let avatar):
            return .joinLobby(name: ProfileText.name(name),
                              avatar: ProfileText.avatar(avatar))
        case .updateLobbyProfile(let name, let avatar):
            return .updateLobbyProfile(name: name.map(ProfileText.name),
                                       avatar: avatar.map(ProfileText.avatar))
        case .setReady(let isReady, _, _, let startSeed, let turnDuration):
            return .setReady(isReady: isReady,
                             startSeed: startSeed,
                             turnDuration: TurnClock.normalized(turnDuration))
        case .leaveLobby:
            return .leaveLobby
        case .gameAction(.raise(let amount)):
            return .gameAction(.raise(to: max(0, amount)))
        case .gameAction(let action):
            return .gameAction(action)
        case .joinGame(let name, let avatar, let startingStack):
            return .joinGame(name: ProfileText.name(name),
                             avatar: ProfileText.avatar(avatar),
                             startingStack: StartingStack.normalized(startingStack))
        case .leaveGame:
            return .leaveGame
        case .dealNextHand(let seed, _, _):
            return .dealNextHand(seed: seed)
        }
    }
}
