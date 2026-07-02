import GameCore

/// Simulates the real iMessage transport: clients never share an object.
func playFullHandOverTheWire(playerCount: Int, seed: UInt64) throws -> GameState {
    let players = (0..<playerCount).map {
        Player(id: "p\($0)", name: "p\($0)", avatar: "🙂", stack: 1000)
    }
    var wire = try GamePayload.encodeToString(
        GameState.startHand(players: players, dealerIndex: 0,
                            smallBlind: 10, bigBlind: 20, seed: seed, handNumber: 1))

    var sends = 0
    while sends < 500 {
        var state = try GamePayload.decode(fromString: wire)
        guard let toAct = state.currentToAct else { break }
        let legal = state.legalActions(for: toAct)
        state.apply(legal.canCheck ? .check : .call, by: toAct)
        wire = try GamePayload.encodeToString(state)
        sends += 1
    }
    return try GamePayload.decode(fromString: wire)
}

/// Simulates the operation protocol over Messages: table state and each action
/// cross the boundary as encoded payloads before the next state is sent.
func playFullHandWithOperationsOverTheWire(playerCount: Int, seed: UInt64) throws -> GameState {
    let players = (0..<playerCount).map {
        Player(id: "p\($0)", name: "p\($0)", avatar: "🙂", stack: 1000)
    }
    var wire = try GamePayload.encodeToString(
        TableMessage.game(
            GameState.startHand(players: players, dealerIndex: 0,
                                smallBlind: 10, bigBlind: 20, seed: seed, handNumber: 1)
        )
    )

    var sends = 0
    while sends < 500 {
        let message = try GamePayload.decodeMessage(fromString: wire)
        guard case .game(let state) = message,
              let toAct = state.currentToAct else { break }

        let actor = state.players[toAct].id
        let legal = state.legalActions(for: toAct)
        let action: PlayerAction = legal.canCheck ? .check : .call
        let operation = TableOperation(id: "op-\(sends)",
                                       actorID: actor,
                                       baseRevision: message.revision,
                                       kind: .gameAction(action))
        let operationWire = try GamePayload.encodeOperationToString(operation)

        guard case .applied(let next) = try message.applyingOperationPayload(operationWire) else {
            break
        }
        wire = try GamePayload.encodeToString(next)
        sends += 1
    }

    guard case .game(let final) = try GamePayload.decodeMessage(fromString: wire) else {
        throw EncodingError.invalidValue(wire, .init(codingPath: [], debugDescription: "Expected final game payload"))
    }
    return final
}
