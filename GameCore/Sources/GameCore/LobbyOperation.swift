import Foundation

extension Lobby {
    func applying(_ operation: TableOperation, now: Date) -> TableOperationResult {
        switch operation.kind {
        case .joinLobby(let name, let avatar):
            return joiningLobby(actorID: operation.actorID, name: name, avatar: avatar,
                                operationID: operation.id)

        case .updateLobbyProfile(let name, let avatar):
            return updatingLobbyProfile(actorID: operation.actorID, name: name, avatar: avatar,
                                        operationID: operation.id)

        case .setReady(let isReady, _, _, let startSeed, let turnDuration):
            return settingLobbyReady(actorID: operation.actorID, isReady: isReady,
                                     startSeed: startSeed, turnDuration: turnDuration,
                                     operationID: operation.id, now: now)

        case .leaveLobby:
            return leavingLobby(actorID: operation.actorID, operationID: operation.id)

        default:
            return .rejected(.wrongPhase)
        }
    }
}
