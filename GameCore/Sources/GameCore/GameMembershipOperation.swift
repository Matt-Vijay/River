import Foundation

extension GameState {
    func joiningGame(actorID: String, name: String, avatar: String,
                     startingStack: Int, operationID: String) -> TableOperationResult {
        guard !isGameOver else { return .rejected(.gameOver) }

        var next = self
        guard next.rejoinOrAddSittingOutPlayer(id: actorID, name: name,
                                               avatar: avatar, stack: startingStack) else {
            return .rejected(.tableFull)
        }
        guard next != self else { return .unchanged(.game(self)) }

        next.version += 1
        return .applied(.game(next).recording(operationID))
    }

    func leavingGame(actorID: String, operationID: String,
                     now: Date) -> TableOperationResult {
        guard !isGameOver else { return .rejected(.gameOver) }
        guard let player = player(id: actorID), !player.hasLeft else {
            return .rejected(.notSeated)
        }

        var next = self
        next.playerLeaves(id: actorID, now: now)
        return .applied(.game(next).recording(operationID))
    }
}
