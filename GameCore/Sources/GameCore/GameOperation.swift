import Foundation

extension GameState {
    func applying(_ operation: TableOperation, now: Date) -> TableOperationResult {
        switch operation.kind {
        case .gameAction(let action):
            return applyingGameAction(action, from: operation, now: now)

        case .joinGame(let name, let avatar, let startingStack):
            return joiningGame(actorID: operation.actorID, name: name, avatar: avatar,
                               startingStack: startingStack, operationID: operation.id)

        case .leaveGame:
            return leavingGame(actorID: operation.actorID, operationID: operation.id, now: now)

        case .dealNextHand(let seed, _, _):
            return dealingNextHand(seed: seed, actorID: operation.actorID,
                                   operationID: operation.id, now: now)

        default:
            return .rejected(.wrongPhase)
        }
    }
}
