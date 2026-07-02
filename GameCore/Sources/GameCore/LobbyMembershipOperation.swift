extension Lobby {
    func joiningLobby(actorID: String, name: String, avatar: String,
                      operationID: String) -> TableOperationResult {
        guard !isFull || contains(actorID) else { return .rejected(.tableFull) }

        let next = adding(id: actorID, name: name, avatar: avatar)
        guard next != self else { return .unchanged(.lobby(self)) }
        return .applied(.lobby(next).recording(operationID))
    }

    func updatingLobbyProfile(actorID: String, name: String?, avatar: String?,
                              operationID: String) -> TableOperationResult {
        guard contains(actorID) else { return .rejected(.notSeated) }

        return .unchanged(.lobby(self))
    }

    func leavingLobby(actorID: String, operationID: String) -> TableOperationResult {
        guard contains(actorID) else { return .rejected(.notSeated) }

        return .applied(.lobby(removing(id: actorID)).recording(operationID))
    }
}
