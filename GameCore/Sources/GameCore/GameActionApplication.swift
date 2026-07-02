import Foundation

extension GameState {
    func applyingGameAction(_ action: PlayerAction, from operation: TableOperation,
                            now: Date) -> TableOperationResult {
        guard !isGameOver else { return .rejected(.gameOver) }
        guard let actorIndex = playerIndex(id: operation.actorID) else {
            return .rejected(.notSeated)
        }

        var next = self
        let didResolveTimeout = next.resolveTimeout(now: now)
        guard !next.isGameOver else { return .rejected(.gameOver) }
        if next.isHandComplete {
            return didResolveTimeout
                ? .applied(.game(next).recording(operation.id))
                : .rejected(.illegalAction)
        }
        guard next.isCurrentPlayer(at: actorIndex) else {
            return didResolveTimeout
                ? .applied(.game(next).recording(operation.id))
                : .rejected(.notActorTurn)
        }

        guard next.apply(action, by: actorIndex, now: now) else {
            return .rejected(.illegalAction)
        }
        return .applied(.game(next).recording(operation.id))
    }
}
