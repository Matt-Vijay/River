import Testing
@testable import GameCore

@Suite("Operation history")
struct OperationHistoryTests {
    @Test("operation history is deduplicated and bounded")
    func operationHistoryIsDeduplicatedAndBounded() {
        let ids = (0..<(OperationIdentity.maxHistory + 8)).map { "op-\($0)" }
        let history = OperationIdentity.history(["op-0", "  ", "op-1", "op-0"] + ids)

        #expect(history.count == OperationIdentity.maxHistory)
        #expect(history.first == "op-8")
        #expect(history.last == "op-\(OperationIdentity.maxHistory + 7)")
        #expect(Set(history).count == history.count)
    }

    @Test("recording trims operation history on lobby and game messages")
    func recordingTrimsOperationHistoryOnMessages() {
        let ids = (0..<OperationIdentity.maxHistory).map { "op-\($0)" }
        let lobbyMessage = TableMessage.lobby(Lobby(tableID: "table-123", appliedOperationIDs: ids))
            .recording("op-\(OperationIdentity.maxHistory)")
        let gameMessage = TableMessage.game(GameState.startHand(
            players: makePlayers([1000, 1000]),
            dealerIndex: 0,
            smallBlind: 10,
            bigBlind: 20,
            seed: 1,
            handNumber: 1,
            tableID: "table-123",
            appliedOperationIDs: ids
        ))
        .recording("op-\(OperationIdentity.maxHistory)")

        #expect(lobbyMessage.appliedOperationIDs.count == OperationIdentity.maxHistory)
        #expect(lobbyMessage.appliedOperationIDs.first == "op-1")
        #expect(lobbyMessage.appliedOperationIDs.last == "op-\(OperationIdentity.maxHistory)")
        #expect(gameMessage.appliedOperationIDs.count == OperationIdentity.maxHistory)
        #expect(gameMessage.appliedOperationIDs.first == "op-1")
        #expect(gameMessage.appliedOperationIDs.last == "op-\(OperationIdentity.maxHistory)")
    }

    @Test("recording ignores blank operation identities")
    func recordingIgnoresBlankOperationIdentities() {
        let lobbyMessage = TableMessage.lobby(Lobby(tableID: "table-123"))
        let gameMessage = headsUpTableMessage()

        #expect(lobbyMessage.recording("   ") == lobbyMessage)
        #expect(gameMessage.recording("") == gameMessage)
    }
}
