import Foundation
import Testing

@testable import GameCore

@Suite("Revision state-machine oracle")
struct RevisionStateMachineTests {
    @Test("dispositions and ordering match exhaustive and seeded oracle cases")
    func dispositionsMatchReferenceOracle() {
        let revisions = fixedRevisions()

        for received in revisions {
            #expect(
                received.production.disposition(comparedTo: nil)
                    == RevisionOracle.classify(received, comparedTo: nil)
            )
            for latest in revisions {
                expectProductionRelationship(received, latest)
            }
        }

        var random = SeededRevisionRandom(state: 0x5249_5645_5252_4556)
        for _ in 0..<4_096 {
            expectProductionRelationship(random.revision(), random.revision())
        }
    }

    @Test("duplicate, stale, forked, phased, and foreign receipts follow one state machine")
    func outOfOrderReceiptSequence() {
        let table = "sequence-table"
        let branch1 = String(repeating: "1", count: 32)
        let branch2 = String(repeating: "2", count: 32)
        let branch3 = String(repeating: "3", count: 32)
        let branchF = String(repeating: "f", count: 32)
        let events = [
            RevisionModel(table, .lobby, 0, branch2),
            RevisionModel(table, .lobby, 2, branch2),
            RevisionModel(table, .lobby, 1, branch3),
            RevisionModel(table, .lobby, 2, branch2),
            RevisionModel(table, .lobby, 2, branch1),
            RevisionModel(table, .lobby, 2, branchF),
            RevisionModel(table, .lobby, 2, branch2),
            RevisionModel(table, .lobby, 2, ""),
            RevisionModel(table, .game, 0, branch3),
            RevisionModel(table, .lobby, Int.max, branchF),
            RevisionModel(table, .game, 0, branch3),
            RevisionModel("foreign-table", .game, Int.max, branchF),
            RevisionModel(table, .game, 1, branch1),
        ]
        let expected: [TableRevisionDisposition] = [
            .firstSeen,
            .newer,
            .stale,
            .duplicate,
            .conflicting(preferred: false),
            .conflicting(preferred: true),
            .conflicting(preferred: false),
            .stale,
            .newer,
            .stale,
            .duplicate,
            .differentTable,
            .newer,
        ]

        var oracle = RevisionOracle()
        var productionLatest: TableRevision?
        var actual: [TableRevisionDisposition] = []
        for event in events {
            let disposition = event.production.disposition(comparedTo: productionLatest)
            actual.append(disposition)
            #expect(disposition == oracle.observe(event))
            if RevisionOracle.replacesLatest(after: disposition) {
                productionLatest = event.production
            }
        }

        #expect(actual == expected)
        #expect(oracle.latest == events.last)
        #expect(productionLatest == events.last?.production)
    }

    @Test("commit preflight gates mutation and preserves idempotent no-ops")
    func commitPreflightMatchesReferenceOracle() throws {
        let source = TableMessage.lobby(Lobby(
            tableID: "commit-table", version: 7,
            seats: [LobbySeat(id: "host", name: "Host", avatar: "H")]
        ))
        let sourceModel = try RevisionModel(source.revision)
        let branch0 = String(repeating: "0", count: 32)
        let branchF = String(repeating: "f", count: 32)
        #expect(sourceModel.branch > branch0)
        #expect(sourceModel.branch < branchF)

        let cases: [(String, RevisionModel?)] = [
            ("first", nil),
            ("duplicate", sourceModel),
            ("older", RevisionModel(sourceModel.tableID, .lobby, 6, branchF)),
            ("newer", RevisionModel(sourceModel.tableID, .lobby, 8, branch0)),
            ("legacy", RevisionModel(sourceModel.tableID, .lobby, 7, "")),
            ("preferred-fork", RevisionModel(sourceModel.tableID, .lobby, 7, branch0)),
            ("losing-fork", RevisionModel(sourceModel.tableID, .lobby, 7, branchF)),
            ("later-phase", RevisionModel(sourceModel.tableID, .game, 0, branch0)),
            ("foreign", RevisionModel("other-table", .lobby, 7, sourceModel.branch)),
        ]

        for (index, entry) in cases.enumerated() {
            let (label, latest) = entry
            let disposition = RevisionOracle.classify(sourceModel, comparedTo: latest)
            let admitted = RevisionOracle.admitsCommit(disposition)
            #expect(
                source.revision.disposition(comparedTo: latest?.production) == disposition,
                "preflight classification: \(label)"
            )

            let changed = source.committing(
                .joinLobby(name: "Guest", avatar: "G"),
                actorID: "guest-\(index)", latestRevision: latest?.production
            )
            let noOp = source.committing(
                .joinLobby(name: "Ignored", avatar: "X"),
                actorID: "host", latestRevision: latest?.production
            )

            if admitted {
                guard case .applied(let next) = changed else {
                    Issue.record("admitted preflight did not apply: \(label)")
                    continue
                }
                try expectValidSuccessor(next, of: sourceModel)
                #expect(noOp == .unchanged, "admitted no-op: \(label)")
            } else {
                #expect(changed == .rejected(.stale), "rejected mutation: \(label)")
                #expect(noOp == .rejected(.stale), "stale no-op: \(label)")
            }
        }

        let game = headsUpTableMessage()
        let gameModel = try RevisionModel(game.revision)
        let olderPhase = RevisionModel(gameModel.tableID, .lobby, Int.max, branchF)
        #expect(RevisionOracle.classify(gameModel, comparedTo: olderPhase) == .newer)
        guard case .applied(let next) = game.committing(
            .gameAction(.fold), actorID: "a", latestRevision: olderPhase.production
        ) else {
            Issue.record("game phase should supersede every lobby version")
            return
        }
        try expectValidSuccessor(next, of: gameModel)
    }

    @Test("counter exhaustion allows the last successor but never a false commit")
    func successorCounterBoundaries() throws {
        let almostExhausted = TableMessage.lobby(Lobby(
            tableID: "boundary-table", version: Int.max - 1,
            seats: [LobbySeat(id: "host", name: "Host", avatar: "H")]
        ))
        let original = try RevisionModel(almostExhausted.revision)
        guard case .applied(.lobby(let finalLobby)) = almostExhausted.committing(
            .joinLobby(name: "Guest", avatar: "G"), actorID: "guest"
        ) else {
            Issue.record("the final representable lobby successor should apply")
            return
        }
        #expect(finalLobby.version == Int.max)
        try expectValidSuccessor(.lobby(finalLobby), of: original)

        let exhaustedLobby = TableMessage.lobby(finalLobby)
        #expect(exhaustedLobby.committing(
            .joinLobby(name: "Third", avatar: "T"), actorID: "third"
        ) == .rejected(.illegalAction))
        #expect(exhaustedLobby.committing(
            .leaveLobby, actorID: "guest"
        ) == .rejected(.illegalAction))
        #expect(exhaustedLobby.committing(
            .startGame(seed: 9, turnDuration: 30), actorID: "host"
        ) == .rejected(.illegalAction))
        #expect(exhaustedLobby.committing(
            .joinLobby(name: "Changed", avatar: "X"), actorID: "host",
            latestRevision: exhaustedLobby.revision
        ) == .unchanged)

        guard case .game(var gameState) = headsUpTableMessage() else { return }
        gameState.version = Int.max - 1
        let finalGameSource = TableMessage.game(gameState)
        let finalGameModel = try RevisionModel(finalGameSource.revision)
        guard case .applied(let finalGame) = finalGameSource.committing(
            .gameAction(.fold), actorID: "a"
        ) else {
            Issue.record("the final representable game successor should apply")
            return
        }
        #expect(finalGame.revision.version == Int.max)
        try expectValidSuccessor(finalGame, of: finalGameModel)

        gameState.version = Int.max
        let exhaustedGame = TableMessage.game(gameState)
        #expect(exhaustedGame.committing(
            .gameAction(.fold), actorID: "a"
        ) == .rejected(.illegalAction))
        #expect(exhaustedGame.committing(
            .joinGame(name: "Alice", avatar: "A", startingStack: 1_000), actorID: "a"
        ) == .unchanged)
    }
}

private struct RevisionModel: Equatable {
    let tableID: String
    let phase: TableRevision.Phase
    let version: Int
    let branch: String

    init(_ tableID: String, _ phase: TableRevision.Phase, _ version: Int, _ branch: String) {
        self.tableID = tableID
        self.phase = phase
        self.version = version
        self.branch = branch
    }

    init(_ revision: TableRevision) throws {
        let data = try JSONEncoder().encode(revision)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let branch = object["branch"] as? String else {
            throw RevisionOracleError.unreadableProductionRevision
        }
        self.init(revision.tableID, revision.phase, revision.version, branch)
    }

    var production: TableRevision {
        TableRevision(tableID: tableID, phase: phase, version: version, branch: branch)
    }
}

private struct RevisionOracle {
    var latest: RevisionModel?

    mutating func observe(_ received: RevisionModel) -> TableRevisionDisposition {
        let disposition = Self.classify(received, comparedTo: latest)
        if Self.replacesLatest(after: disposition) { latest = received }
        return disposition
    }

    static func classify(
        _ received: RevisionModel, comparedTo latest: RevisionModel?
    ) -> TableRevisionDisposition {
        guard let latest else { return .firstSeen }
        guard received.tableID == latest.tableID else { return .differentTable }
        if received.phase != latest.phase {
            return received.phase.rawValue > latest.phase.rawValue ? .newer : .stale
        }
        if received.version != latest.version {
            return received.version > latest.version ? .newer : .stale
        }
        if received.branch == latest.branch { return .duplicate }
        if latest.branch.isEmpty { return .newer }
        if received.branch.isEmpty { return .stale }
        return .conflicting(preferred: received.branch > latest.branch)
    }

    static func admitsCommit(_ disposition: TableRevisionDisposition) -> Bool {
        switch disposition {
        case .differentTable, .stale, .conflicting(preferred: false): false
        default: true
        }
    }

    static func replacesLatest(after disposition: TableRevisionDisposition) -> Bool {
        switch disposition {
        case .firstSeen, .newer, .conflicting(preferred: true): true
        default: false
        }
    }
}

private enum RevisionOracleError: Error {
    case unreadableProductionRevision
}

private func expectProductionRelationship(_ received: RevisionModel, _ latest: RevisionModel) {
    let disposition = RevisionOracle.classify(received, comparedTo: latest)
    let isOlder: Bool
    switch disposition {
    case .stale, .conflicting(preferred: false): isOlder = true
    default: isOlder = false
    }
    let conflicts = received.tableID == latest.tableID
        && received.phase == latest.phase
        && received.version == latest.version
        && !received.branch.isEmpty
        && !latest.branch.isEmpty
        && received.branch != latest.branch

    #expect(received.production.disposition(comparedTo: latest.production) == disposition)
    #expect(received.production.isOlder(than: latest.production) == isOlder)
    #expect(
        received.production.isSameOrNewer(than: latest.production)
            == (received.tableID == latest.tableID && !isOlder)
    )
    #expect(received.production.conflicts(with: latest.production) == conflicts)
}

private func expectValidSuccessor(
    _ next: TableMessage, of previous: RevisionModel
) throws {
    let nextModel = try RevisionModel(next.revision)
    #expect(nextModel.tableID == previous.tableID)
    #expect(RevisionOracle.classify(nextModel, comparedTo: previous) == .newer)
    #expect(previous.production.isOlder(than: next.revision))
}

private func fixedRevisions() -> [RevisionModel] {
    let branches = [
        "",
        String(repeating: "0", count: 32),
        String(repeating: "1", count: 32),
        String(repeating: "f", count: 32),
    ]
    return ["table-a", "table-b"].flatMap { table in
        [TableRevision.Phase.lobby, .game].flatMap { phase in
            [0, 1, 2, Int.max - 1, Int.max].flatMap { version in
                branches.map { RevisionModel(table, phase, version, $0) }
            }
        }
    }
}

private struct SeededRevisionRandom {
    var state: UInt64

    mutating func revision() -> RevisionModel {
        let tableID = "fuzz-table-\(next() % 3)"
        let phase: TableRevision.Phase = next() & 1 == 0 ? .lobby : .game
        let version: Int = switch next() % 8 {
        case 0: 0
        case 1: 1
        case 2: Int.max - 1
        case 3: Int.max
        default: Int(next() % UInt64(Int.max))
        }
        let branch = next() % 5 == 0 ? "" : paddedHex(next()) + paddedHex(next())
        return RevisionModel(tableID, phase, version, branch)
    }

    private mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }

    private func paddedHex(_ value: UInt64) -> String {
        let value = String(value, radix: 16)
        return String(repeating: "0", count: 16 - value.count) + value
    }
}
