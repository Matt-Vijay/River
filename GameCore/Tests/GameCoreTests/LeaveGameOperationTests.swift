import Testing
import Foundation
@testable import GameCore

@Suite("Leave game operations")
struct LeaveGameOperationTests {
    @Test("non-current leave operation advances the game revision")
    func nonCurrentLeaveAdvancesRevision() throws {
        let message = headsUpTableMessage()
        let operation = TableOperation(id: "op-1", actorID: "b", baseRevision: message.revision,
                                       kind: .leaveGame)

        guard case .applied(.game(let next)) = message.applying(operation),
              let bob = next.player(id: "b") else {
            Issue.record("expected applied game")
            return
        }

        #expect(bob.hasLeft)
        #expect(next.version == message.revision.version + 1)
        #expect(next.results?.first?.playerID == "a")
        #expect(next.appliedOperationIDs == ["op-1"])
    }

    @Test("already-left player cannot record another leave operation")
    func alreadyLeftPlayerCannotLeaveAgain() throws {
        let message = TableMessage.game(
            Lobby(tableID: "table-123")
                .adding(id: "a", name: "Alice", avatar: "A")
                .adding(id: "b", name: "Bob", avatar: "B")
                .adding(id: "c", name: "Cara", avatar: "C")
                .start(seed: 1)
        )
        let firstLeave = TableOperation(id: "op-1", actorID: "b", baseRevision: message.revision,
                                        kind: .leaveGame)
        let firstResult = message.applying(firstLeave)
        guard case .applied(let departedMessage) = firstResult else {
            Issue.record("expected first leave to apply")
            return
        }

        let secondLeave = TableOperation(id: "op-2", actorID: "b",
                                         baseRevision: departedMessage.revision,
                                         kind: .leaveGame)

        #expect(departedMessage.applying(secondLeave) == .rejected(.notSeated))
    }

    @Test("leave operations cannot mutate a finished game")
    func leaveOperationCannotMutateFinishedGame() throws {
        let message = headsUpTableMessage()
        let firstLeave = TableOperation(id: "op-1", actorID: "b", baseRevision: message.revision,
                                        kind: .leaveGame)
        let firstResult = message.applying(firstLeave)
        guard case .applied(.game(let finishedState)) = firstResult else {
            Issue.record("expected first leave to finish the game")
            return
        }
        let finishedMessage = TableMessage.game(finishedState)

        let winnerLeave = TableOperation(id: "op-2", actorID: "a",
                                         baseRevision: finishedMessage.revision,
                                         kind: .leaveGame)

        #expect(finishedMessage.applying(winnerLeave) == .rejected(.gameOver))
    }
}
