import Foundation

extension Lobby {
    func settingLobbyReady(actorID: String, isReady: Bool, startSeed: UInt64,
                           turnDuration: TimeInterval,
                           operationID: String,
                           now: Date) -> TableOperationResult {
        guard contains(actorID) else { return .rejected(.notSeated) }

        var next = self
        next.updateSeat(id: actorID, isReady: isReady)
        guard next != self else { return .unchanged(.lobby(self)) }

        if let state = next.startIfReady(seed: startSeed, turnDuration: turnDuration, now: now) {
            return .applied(
                .game(state).recording(operationID)
            )
        }

        return .applied(.lobby(next).recording(operationID))
    }
}
