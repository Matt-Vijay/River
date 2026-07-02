import Testing
import Foundation
@testable import GameCore

@Suite("Join game operations")
struct JoinGameOperationTests {
    @Test("blank actors cannot join a game")
    func blankActorsCannotJoinGame() {
        let message = headsUpTableMessage()
        let operation = TableOperation(id: "op-1", actorID: "", baseRevision: message.revision,
                                       kind: .joinGame(name: "Cara",
                                                       avatar: "C",
                                                       startingStack: 1000))

        #expect(message.applying(operation) == .rejected(.notSeated))
    }

    @Test("join game preserves active player identity without sitting them out")
    func joinGamePreservesActivePlayerIdentityAndStatus() {
        let message = headsUpTableMessage()
        let operation = TableOperation(id: "op-1", actorID: "a", baseRevision: message.revision,
                                       kind: .joinGame(name: "Updated Alice",
                                                       avatar: "A2",
                                                       startingStack: 1000))

        #expect(message.applying(operation) == .unchanged(message))
    }

    @Test("departed players rejoin with chips when their old stack is empty")
    func departedPlayersRejoinWithChipsWhenOldStackIsEmpty() throws {
        var state = GameState.startHand(players: makePlayers([0, 1000, 1000]),
                                        dealerIndex: 1,
                                        smallBlind: 10,
                                        bigBlind: 20,
                                        seed: 1,
                                        handNumber: 1,
                                        tableID: "table-123")
        state.players[0].hasLeft = true
        state.players[0].status = .sittingOut
        let message = TableMessage.game(state)
        let operation = TableOperation(id: "op-1", actorID: "p0",
                                       baseRevision: message.revision,
                                       kind: .joinGame(name: "P0",
                                                       avatar: "A",
                                                       startingStack: 1000))

        guard case .applied(.game(let next)) = message.applying(operation),
              let rejoined = next.player(id: "p0") else {
            Issue.record("expected departed player to rejoin")
            return
        }

        #expect(!rejoined.hasLeft)
        #expect(rejoined.status == .sittingOut)
        #expect(rejoined.stack == 1000)
    }

    @Test("rejoin helper normalizes invalid buy-ins")
    func rejoinHelperNormalizesInvalidBuyIns() throws {
        var state = GameState.startHand(players: makePlayers([0, 1000, 1000]),
                                        dealerIndex: 1,
                                        smallBlind: 10,
                                        bigBlind: 20,
                                        seed: 1,
                                        handNumber: 1,
                                        tableID: "table-123")
        state.players[0].hasLeft = true
        state.players[0].status = .sittingOut

        let didRejoin = state.rejoinOrAddSittingOutPlayer(id: "p0", name: "P0", avatar: "A", stack: -50)
        let rejoined = try #require(state.player(id: "p0"))

        #expect(didRejoin)
        #expect(!rejoined.hasLeft)
        #expect(rejoined.status == .sittingOut)
        #expect(rejoined.stack == StartingStack.defaultAmount)
    }

    @Test("new sitting-out joins normalize invalid buy-ins")
    func newSittingOutJoinsNormalizeInvalidBuyIns() throws {
        var state = GameState.startHand(players: makePlayers([1000, 1000]),
                                        dealerIndex: 0,
                                        smallBlind: 10,
                                        bigBlind: 20,
                                        seed: 1,
                                        handNumber: 1,
                                        tableID: "table-123")

        let didJoin = state.rejoinOrAddSittingOutPlayer(id: "new", name: "New", avatar: "N", stack: 0)
        let joined = try #require(state.player(id: "new"))

        #expect(didJoin)
        #expect(joined.status == .sittingOut)
        #expect(joined.stack == StartingStack.defaultAmount)
    }

    @Test("players cannot join a game after it has an overall winner")
    func playersCannotJoinAfterGameOver() throws {
        var state = GameState.startHand(players: makePlayers([1000, 1000]),
                                        dealerIndex: 0,
                                        smallBlind: 10,
                                        bigBlind: 20,
                                        seed: 1,
                                        handNumber: 1)
        let didLeave = state.playerLeaves(id: "p1")
        let message = TableMessage.game(state)
        let operation = TableOperation(id: "op-1", actorID: "observer",
                                       baseRevision: message.revision,
                                       kind: .joinGame(name: "Rook",
                                                       avatar: "R",
                                                       startingStack: 1000))

        #expect(didLeave)
        #expect(state.overallWinner?.id == "p0")
        #expect(message.applying(operation) == .rejected(.gameOver))
    }
}
