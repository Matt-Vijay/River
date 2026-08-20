import Testing
@testable import GameCore

@Suite("Table revisions")
struct TableRevisionTests {
    @Test("table identity survives lobby start and next hand")
    func tableIdentitySurvivesProgression() throws {
        let lobby = Lobby(tableID: "table-123")
            .fixtureSeat(id: "a", name: "Alice", avatar: "🙂")
            .fixtureSeat(id: "b", name: "Bob", avatar: "🙂")
        guard case .applied(.game(var state)) = TableMessage.lobby(lobby).committing(
            .startGame(seed: 1, turnDuration: 30),
            actorID: "b"
        ) else {
            Issue.record("expected lobby to start")
            return
        }
        state.apply(.fold, by: 0)
        let next = state.startNextHand(seed: 2)

        #expect(state.tableID == "table-123")
        #expect(next?.tableID == "table-123")
    }

    @Test("message revisions order lobby, game, and newer game states")
    func messageRevisionOrdering() {
        let lobby = Lobby(tableID: "table-123")
        let older = GameState.startHand(players: [
            Player(id: "a", name: "Alice", avatar: "🙂", stack: 1000),
            Player(id: "b", name: "Bob", avatar: "🙂", stack: 1000),
        ], dealerIndex: 0, smallBlind: 10, bigBlind: 20, seed: 1,
           handNumber: 1, tableID: "table-123")
        var newer = older
        let didApply = newer.apply(.fold, by: 0)
        #expect(didApply)

        let lobbyRevision = TableMessage.lobby(lobby).revision
        let olderRevision = TableMessage.game(older).revision
        let newerRevision = TableMessage.game(newer).revision
        #expect(lobbyRevision.isOlder(than: olderRevision))
        #expect(olderRevision.isOlder(than: newerRevision))
        #expect(!newerRevision.isOlder(than: olderRevision))
        #expect(newerRevision.isSameOrNewer(than: olderRevision))
        #expect(newerRevision.isSameOrNewer(than: newerRevision))
        #expect(!olderRevision.isSameOrNewer(than: newerRevision))
        #expect(!newerRevision.isSameOrNewer(
            than: TableRevision(tableID: "different", phase: .game, version: 0)
        ))
    }

}
