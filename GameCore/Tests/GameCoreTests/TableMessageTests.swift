import Testing
import Foundation
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

    @Test("receipt dispositions distinguish replay, order, table, and conflicts")
    func revisionDispositions() throws {
        let base = TableMessage.lobby(
            Lobby(tableID: "table-123")
                .fixtureSeat(id: "host", name: "Host", avatar: "H")
        )
        guard case .applied(let left) = base.committing(
            .joinLobby(name: "Alice", avatar: "A"), actorID: "a"
        ), case .applied(let right) = base.committing(
            .joinLobby(name: "Bob", avatar: "B"), actorID: "b"
        ) else {
            Issue.record("expected concurrent branches")
            return
        }

        #expect(base.revision.disposition(comparedTo: nil) == .firstSeen)
        #expect(base.revision.disposition(comparedTo: base.revision) == .duplicate)
        #expect(left.revision.disposition(comparedTo: base.revision) == .newer)
        #expect(base.revision.disposition(comparedTo: left.revision) == .stale)
        #expect(
            base.revision.disposition(comparedTo: Lobby(tableID: "other").message.revision)
                == .differentTable
        )
        #expect(left.revision.conflicts(with: right.revision))
        #expect(
            left.revision.disposition(comparedTo: right.revision)
                == .conflicting(preferred: left.revision.isSameOrNewer(than: right.revision))
        )
    }

    @Test("legacy revision fingerprints migrate and corrupt revisions are rejected")
    func revisionPersistenceValidation() throws {
        let revision = TableMessage.lobby(Lobby(tableID: "table-123")).revision
        var legacy = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(revision)) as? [String: Any]
        )
        legacy.removeValue(forKey: "branch")
        let migrated = try JSONDecoder().decode(
            TableRevision.self,
            from: JSONSerialization.data(withJSONObject: legacy)
        )
        #expect(revision.disposition(comparedTo: migrated) == .newer)

        for mutation in [
            { (object: inout [String: Any]) in object["version"] = -1 },
            { (object: inout [String: Any]) in object["branch"] = "not-a-digest" },
            { (object: inout [String: Any]) in
                object["tableID"] = String(
                    repeating: "t", count: Identity.maximumUTF8Length + 1)
            },
        ] {
            var object = legacy
            mutation(&object)
            #expect(throws: DecodingError.self) {
                _ = try JSONDecoder().decode(
                    TableRevision.self,
                    from: JSONSerialization.data(withJSONObject: object)
                )
            }
        }
    }

    @Test("operation authority is scoped to a valid local actor and table")
    func operationAuthorityScope() throws {
        let message = headsUpTableMessage()
        let otherTable = TableMessage.lobby(Lobby(tableID: "other")).revision

        #expect(TableActor("  a  ")?.id == "a")
        #expect(TableActor("a\u{0}b") == nil)
        #expect(TableActor(String(
            repeating: "a", count: Identity.maximumUTF8Length + 1
        )) == nil)
        #expect(message.committing(
            .gameAction(.fold), actorID: "a", latestRevision: otherTable
        ) == .rejected(.stale))
    }
}

private extension Lobby {
    var message: TableMessage { .lobby(self) }
}

@Suite("Table summaries")
struct TableSummaryTests {
    @Test("message summary describes seated lobby players")
    func lobbyMessageSummary() {
        let lobby = Lobby(maxPlayers: 6, seats: [
            LobbySeat(id: "host", name: "Alice", avatar: "A"),
            LobbySeat(id: "guest", name: "Bob", avatar: "B"),
        ])

        let summary = GamePayload.summary(for: .lobby(lobby))

        #expect(summary == "Lobby · 2/6 seated")
    }

    @Test("summary describes the live hand")
    func liveSummary() {
        let state = sixPlayerState()
        let summary = GamePayload.summary(for: state)
        #expect(summary.contains("Pre-flop"))
        #expect(summary.contains("to act"))
    }

    @Test("summary describes the result at showdown")
    func resultSummary() {
        var state = GameState.startHand(players: [
            Player(id: "a", name: "Alice", avatar: "🙂", stack: 1000),
            Player(id: "b", name: "Bob", avatar: "🙂", stack: 1000),
        ], dealerIndex: 0, smallBlind: 10, bigBlind: 20, seed: 1, handNumber: 1)
        state.apply(.fold, by: 0)
        let summary = GamePayload.summary(for: state)
        #expect(summary.contains("Bob won"))
        // Bob's unmatched 10-chip blind layer is returned, not part of the pot won.
        #expect(state.displayPot == 20)
    }

    @Test("summary describes the overall game winner")
    func gameOverSummary() {
        var state = GameState.startHand(players: [
            Player(id: "a", name: "Alice", avatar: "A", stack: 1000),
            Player(id: "b", name: "Bob", avatar: "B", stack: 1000),
        ], dealerIndex: 0, smallBlind: 10, bigBlind: 20, seed: 1, handNumber: 1)
        let didLeave = state.playerLeaves(id: "b")

        let summary = GamePayload.summary(for: state)

        #expect(didLeave)
        #expect(state.overallWinner?.name == "Alice")
        #expect(summary == "Alice wins the game")
    }
}
