extension TableMessage {
    var appliedOperationIDs: [String] {
        switch self {
        case .lobby(let lobby):
            return lobby.appliedOperationIDs
        case .game(let state):
            return state.appliedOperationIDs
        }
    }

    func recording(_ operationID: String) -> TableMessage {
        let operationID = OperationIdentity.normalized(operationID)
        guard !operationID.isEmpty else { return self }
        switch self {
        case .lobby(var lobby):
            if !lobby.appliedOperationIDs.contains(operationID) {
                lobby.appliedOperationIDs.append(operationID)
                lobby.appliedOperationIDs = OperationIdentity.history(lobby.appliedOperationIDs)
            }
            return .lobby(lobby)

        case .game(var state):
            if !state.appliedOperationIDs.contains(operationID) {
                state.appliedOperationIDs.append(operationID)
                state.appliedOperationIDs = OperationIdentity.history(state.appliedOperationIDs)
            }
            return .game(state)
        }
    }
}
