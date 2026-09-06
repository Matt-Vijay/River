import Testing
import Foundation
@testable import GameCore

@Suite("Table revisions")
struct TableRevisionTests {
    @Test("device-local sender aliases bind once and survive persistence")
    func participantBindings() throws {
        let alice = try #require(TableActor("alice-seat"))
        let bob = try #require(TableActor("bob-seat"))
        var onBob = TableParticipants()
        let bound = onBob.bind(alice, senderID: "alice-on-bob-device", localID: bob.id)
        #expect(bound)
        var restored = try JSONDecoder().decode(
            TableParticipants.self, from: JSONEncoder().encode(onBob)
        )
        let cases: [(TableActor, String, Bool)] = [
            (alice, "alice-on-bob-device", true),
            (bob, bob.id, true),
            (alice, bob.id, false),
            (bob, "alice-on-bob-device", false),
            (alice, "another-sender", false),
            (try #require(TableActor("changed-seat")), "alice-on-bob-device", false),
        ]
        for (actor, sender, expected) in cases {
            let accepted = restored.bind(actor, senderID: sender, localID: bob.id)
            #expect(accepted == expected)
        }
        var onAlice = TableParticipants()
        let remoteBound = onAlice.bind(bob, senderID: "bob-on-alice-device", localID: alice.id)
        let localBound = onAlice.bind(alice, senderID: alice.id, localID: alice.id)
        #expect(remoteBound && localBound)
    }

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

    @Test("concurrent equal-version states have one deterministic successor")
    func concurrentBranches() {
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

        #expect(left.revision.version == right.revision.version)
        #expect(left.revision != right.revision)
        let preferred = left.revision.isOlder(than: right.revision) ? right : left
        let rejected = preferred == left ? right : left
        #expect(rejected.revision.isOlder(than: preferred.revision))
        #expect(!preferred.revision.isOlder(than: rejected.revision))
        #expect(rejected.committing(
            .leaveLobby, actorID: "host", latestRevision: preferred.revision
        ) == .rejected(.stale))
        guard case .applied = preferred.committing(
            .leaveLobby, actorID: "host", latestRevision: rejected.revision
        ) else {
            Issue.record("preferred branch must remain actionable")
            return
        }
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
        #expect(migrated.isOlder(than: revision))
        #expect(!revision.isOlder(than: migrated))

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

    @Test("out-of-order messages converge without reviving stale or foreign tables")
    func outOfOrderSequence() {
        let events: [(String, TableRevision.Phase, Int, String, Bool)] = [
            ("sequence", .lobby, 0, "2", true),
            ("sequence", .lobby, 2, "2", true),
            ("sequence", .lobby, 1, "3", false),
            ("sequence", .lobby, 2, "2", true),
            ("sequence", .lobby, 2, "1", false),
            ("sequence", .lobby, 2, "f", true),
            ("sequence", .lobby, 2, "2", false),
            ("sequence", .lobby, 2, "", false),
            ("sequence", .game, 0, "3", true),
            ("sequence", .lobby, Int.max, "f", false),
            ("sequence", .game, 0, "3", true),
            ("foreign", .game, Int.max, "f", false),
            ("sequence", .game, 1, "1", true),
        ]
        var latest: TableRevision?
        for (tableID, phase, version, branch, expected) in events {
            let received = TableRevision(
                tableID: tableID,
                phase: phase, version: version, branch: String(repeating: branch, count: 32)
            )
            let accepted = latest.map { received.isSameOrNewer(than: $0) } ?? true
            #expect(accepted == expected)
            if accepted { latest = received }
        }
        #expect(latest?.phase == .game)
        #expect(latest?.version == 1)
    }

    @Test("revision preflight also protects idempotent joins")
    func idempotentJoinPreflight() {
        let source = TableMessage.lobby(Lobby(
            tableID: "commit-table", version: 7,
            seats: [LobbySeat(id: "host", name: "Host", avatar: "H")]
        ))
        let low = String(repeating: "0", count: 32)
        let high = String(repeating: "f", count: 32)
        #expect(source.revision.branch > low && source.revision.branch < high)
        let cases: [(TableRevision?, Bool)] = [
            (nil, true),
            (source.revision, true),
            (TableRevision(tableID: "commit-table", phase: .lobby, version: 6, branch: high), true),
            (TableRevision(tableID: "commit-table", phase: .lobby, version: 8, branch: low), false),
            (TableRevision(tableID: "commit-table", phase: .lobby, version: 7), true),
            (TableRevision(tableID: "commit-table", phase: .lobby, version: 7, branch: low), true),
            (TableRevision(tableID: "commit-table", phase: .lobby, version: 7, branch: high), false),
            (TableRevision(tableID: "commit-table", phase: .game, version: 0), false),
            (TableRevision(tableID: "foreign", phase: .lobby, version: 7), false),
        ]
        for (latest, admitted) in cases {
            #expect(source.committing(
                .joinLobby(name: "Ignored", avatar: "X"), actorID: "host", latestRevision: latest
            ) == (admitted ? .unchanged : .rejected(.stale)))
        }
    }

    @Test("the final representable lobby and game revisions can still commit")
    func finalSuccessor() throws {
        let lobby = Lobby(tableID: "boundary-table", version: Int.max - 1)
        guard case .game(var game) = headsUpTableMessage() else {
            Issue.record("expected game fixture")
            return
        }
        game.version = Int.max - 1
        let cases: [(TableMessage, TableOperation)] = [
            (.lobby(lobby), .joinLobby(name: "Alice", avatar: "A")),
            (.game(game), .gameAction(.fold)),
        ]
        for (source, operation) in cases {
            guard case .applied(let next) = source.committing(operation, actorID: "a") else {
                Issue.record("expected final successor for \(operation)")
                continue
            }
            #expect(next.revision.version == Int.max)
            #expect(next.revision.tableID == source.revision.tableID)
            #expect(source.revision.isOlder(than: next.revision))
        }
    }
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
