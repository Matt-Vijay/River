import Testing
import Foundation
@testable import GameCore

@Suite("Game action operations")
struct GameActionOperationTests {
    @Test("game action applies only when based on the current revision")
    func gameActionRequiresCurrentRevision() {
        let message = headsUpTableMessage()
        let stale = TableRevision(tableID: "table-123", phase: .game, version: 99)
        let operation = TableOperation(id: "op-1", actorID: "a", baseRevision: stale,
                                       kind: .gameAction(.fold))

        #expect(message.applying(operation) == .rejected(.stale(expected: message.revision)))
    }

    @Test("game action preflight rejects locally stale selected messages")
    func gameActionPreflightRejectsLocallyStaleSelectedMessages() {
        let message = headsUpTableMessage()
        let latest = TableRevision(tableID: message.revision.tableID,
                                   phase: message.revision.phase,
                                   version: message.revision.version + 1)
        let tracker = TableRevisionTracker(revisions: [latest])
        let operation = TableOperation(id: "op-1", actorID: "a",
                                       baseRevision: message.revision,
                                       kind: .gameAction(.fold))

        #expect(message.applying(operation, knownBy: tracker) == .rejected(.stale(expected: latest)))
    }

    @Test("duplicate game action replay is acknowledged before stale preflight")
    func duplicateGameActionReplayIsAcknowledgedBeforeStalePreflight() {
        guard case .game(var state) = headsUpTableMessage() else {
            Issue.record("expected game message")
            return
        }
        state.appliedOperationIDs = ["op-1"]
        let message = TableMessage.game(state)
        let latest = TableRevision(tableID: message.revision.tableID,
                                   phase: message.revision.phase,
                                   version: message.revision.version + 1)
        let tracker = TableRevisionTracker(revisions: [latest])
        let operation = TableOperation(id: "op-1", actorID: "a",
                                       baseRevision: message.revision,
                                       kind: .gameAction(.fold))

        #expect(message.applying(operation, knownBy: tracker) == .unchanged(message))
    }

    @Test("game action applies only for the player whose turn it is")
    func gameActionRequiresActorTurn() {
        let message = headsUpTableMessage()
        let operation = TableOperation(id: "op-1", actorID: "b", baseRevision: message.revision,
                                       kind: .gameAction(.fold))

        #expect(message.applying(operation) == .rejected(.notActorTurn))
    }

    @Test("illegal game action is rejected without recording the operation")
    func illegalGameActionRejected() {
        let message = headsUpTableMessage()
        let operation = TableOperation(id: "op-1", actorID: "a", baseRevision: message.revision,
                                       kind: .gameAction(.check))

        #expect(message.applying(operation) == .rejected(.illegalAction))
    }

    @Test("game actions cannot mutate a finished game")
    func gameActionCannotMutateFinishedGame() throws {
        let message = headsUpTableMessage()
        let finish = TableOperation(id: "op-1", actorID: "b", baseRevision: message.revision,
                                    kind: .leaveGame)
        guard case .applied(.game(let finishedState)) = message.applying(finish) else {
            Issue.record("expected first action to finish the game")
            return
        }
        let finishedMessage = TableMessage.game(finishedState)

        let lateAction = TableOperation(id: "op-2", actorID: "a",
                                        baseRevision: finishedMessage.revision,
                                        kind: .gameAction(.call))

        #expect(finishedMessage.applying(lateAction) == .rejected(.gameOver))
    }

    @Test("game action resolves a timed-out prior actor before checking turn")
    func gameActionResolvesTimeoutBeforeTurnCheck() throws {
        let start = Date()
        let state = GameState.startHand(players: [
            Player(id: "a", name: "Alice", avatar: "A", stack: 1000),
            Player(id: "b", name: "Bob", avatar: "B", stack: 1000),
            Player(id: "c", name: "Cara", avatar: "C", stack: 1000),
        ], dealerIndex: 0, smallBlind: 10, bigBlind: 20,
           seed: 1, handNumber: 1, tableID: "table-123",
           turnDuration: 30, now: start)
        let message = TableMessage.game(state)
        let operation = TableOperation(id: "op-1", actorID: "b", baseRevision: message.revision,
                                       kind: .gameAction(.call))

        guard case .applied(.game(let next)) = message.applying(
            operation,
            now: start.addingTimeInterval(45)
        ) else {
            Issue.record("expected applied game")
            return
        }

        #expect(next.players[0].status == .folded)
        #expect(next.players[1].lastAction == .call)
        #expect(next.appliedOperationIDs == ["op-1"])
    }

    @Test("game action commits timeout-only turn advance when caller is not next")
    func gameActionCommitsTimeoutOnlyTurnAdvanceWhenCallerIsNotNext() throws {
        let start = Date()
        let state = GameState.startHand(players: [
            Player(id: "a", name: "Alice", avatar: "A", stack: 1000),
            Player(id: "b", name: "Bob", avatar: "B", stack: 1000),
            Player(id: "c", name: "Cara", avatar: "C", stack: 1000),
        ], dealerIndex: 0, smallBlind: 10, bigBlind: 20,
           seed: 1, handNumber: 1, tableID: "table-123",
           turnDuration: 30, now: start)
        let message = TableMessage.game(state)
        let operation = TableOperation(id: "op-1", actorID: "c", baseRevision: message.revision,
                                       kind: .gameAction(.call))

        guard case .applied(.game(let next)) = message.applying(
            operation,
            now: start.addingTimeInterval(45)
        ) else {
            Issue.record("expected timeout advance to be sent")
            return
        }

        #expect(next.players[0].status == .folded)
        #expect(next.currentPlayer?.id == "b")
        #expect(next.players[2].lastAction == nil)
        #expect(next.appliedOperationIDs == ["op-1"])
    }

    @Test("game action commits hand completion created by timeout resolution")
    func gameActionCommitsHandCompletionCreatedByTimeoutResolution() throws {
        let start = Date()
        let state = GameState.startHand(players: [
            Player(id: "a", name: "Alice", avatar: "A", stack: 1000),
            Player(id: "b", name: "Bob", avatar: "B", stack: 1000),
        ], dealerIndex: 0, smallBlind: 10, bigBlind: 20,
           seed: 1, handNumber: 1, tableID: "table-123",
           turnDuration: 30, now: start)
        let message = TableMessage.game(state)
        let operation = TableOperation(id: "op-1", actorID: "b", baseRevision: message.revision,
                                       kind: .gameAction(.call))

        guard case .applied(.game(let next)) = message.applying(
            operation,
            now: start.addingTimeInterval(45)
        ) else {
            Issue.record("expected timeout-completed hand to be sent")
            return
        }

        #expect(next.isHandComplete)
        #expect(next.players[0].status == .folded)
        #expect(next.results?.first?.playerID == "b")
        #expect(next.appliedOperationIDs == ["op-1"])
    }

    @Test("valid game action produces the next game revision")
    func validGameActionApplies() throws {
        let message = headsUpTableMessage()
        let operation = TableOperation(id: "op-1", actorID: "a", baseRevision: message.revision,
                                       kind: .gameAction(.fold))

        guard case .applied(.game(let next)) = message.applying(operation) else {
            Issue.record("expected applied game")
            return
        }
        #expect(next.version > message.revision.version)
        #expect(next.results?.first?.playerID == "b")
        #expect(next.appliedOperationIDs == ["op-1"])
    }

    @Test("committing a game action applies an encoded operation envelope")
    func committingGameActionAppliesEncodedOperationEnvelope() throws {
        let message = headsUpTableMessage()

        guard case .applied(.game(let next)) = try message.committing(
            .gameAction(.fold),
            actorID: "a",
            operationID: "op-1"
        ) else {
            Issue.record("Expected commit to apply")
            return
        }

        #expect(next.version > message.revision.version)
        #expect(next.results?.first?.playerID == "b")
        #expect(next.appliedOperationIDs == ["op-1"])
    }

    @Test("game actions trim actor identities before applying")
    func gameActionsTrimActorIdentitiesBeforeApplying() throws {
        let message = headsUpTableMessage()
        let operation = TableOperation(id: "op-1", actorID: "  a  ",
                                       baseRevision: message.revision,
                                       kind: .gameAction(.fold))

        guard case .applied(.game(let next)) = message.applying(operation) else {
            Issue.record("expected applied game")
            return
        }

        #expect(operation.actorID == "a")
        #expect(next.results?.first?.playerID == "b")
    }

    @Test("duplicate operation is acknowledged without changing state")
    func duplicateOperationIsAcknowledgedWithoutChangingState() {
        var state = GameState.startHand(players: [
            Player(id: "a", name: "Alice", avatar: "A", stack: 1000),
            Player(id: "b", name: "Bob", avatar: "B", stack: 1000),
        ], dealerIndex: 0, smallBlind: 10, bigBlind: 20,
           seed: 1, handNumber: 1, tableID: "table-123")
        state.appliedOperationIDs = ["op-1"]
        let message = TableMessage.game(state)
        let operation = TableOperation(id: "op-1", actorID: "a", baseRevision: message.revision,
                                       kind: .gameAction(.fold))

        #expect(message.applying(operation) == .unchanged(message))
    }

    @Test("empty operation identities are rejected")
    func emptyOperationIdentitiesAreRejected() {
        let message = headsUpTableMessage()
        let operation = TableOperation(id: "", actorID: "a", baseRevision: message.revision,
                                       kind: .gameAction(.fold))

        #expect(operation.id.isEmpty)
        #expect(message.applying(operation) == .rejected(.invalidOperationIdentity))
    }

    @Test("operation identities are trimmed and blank identities stay invalid")
    func operationIdentitiesAreTrimmedAndBlankIdentitiesStayInvalid() {
        let message = headsUpTableMessage()
        let padded = TableOperation(id: "  op-1  ", actorID: "a", baseRevision: message.revision,
                                    kind: .gameAction(.fold))
        let blank = TableOperation(id: "   ", actorID: "a", baseRevision: message.revision,
                                   kind: .gameAction(.fold))

        #expect(padded.id == "op-1")
        #expect(blank.id.isEmpty)
    }

    @Test("blank operation identities are not recorded")
    func blankOperationIdentitiesAreNotRecorded() throws {
        let message = headsUpTableMessage()
        let operation = TableOperation(id: "", actorID: "a", baseRevision: message.revision,
                                       kind: .gameAction(.fold))

        #expect(message.applying(operation) == .rejected(.invalidOperationIdentity))
        #expect(message.recording(operation.id) == message)
    }
}
