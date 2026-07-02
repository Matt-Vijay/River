import Foundation

extension GameState {
    func dealingNextHand(seed: UInt64, actorID: String, operationID: String,
                         now: Date) -> TableOperationResult {
        guard fundedPlayerCount >= 2 else { return .rejected(.gameOver) }
        guard let actor = player(id: actorID), !actor.hasLeft else {
            return .rejected(.notSeated)
        }
        guard isHandComplete else { return .rejected(.illegalAction) }
        guard canDealNextHand(actorID: actorID) else { return .rejected(.notSeated) }

        guard let next = startNextHand(seed: seed, now: now) else {
            return .rejected(.gameOver)
        }

        return .applied(.game(next).recording(operationID))
    }
}
