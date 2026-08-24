import Foundation
import Testing

@testable import GameCore

@Suite("Table operation authority matrix")
struct AuthorityMatrixTests {
    @Test("all operations reject or apply consistently across phase and actor classes")
    func operationPhaseActorMatrix() throws {
        let fixtures = try AuthorityFixtures()
        var rowCount = 0

        for phase in AuthorityPhase.allCases {
            let source = fixtures.message(for: phase)
            for operation in AuthorityOperation.allCases {
                let validActorOutcomes = expectedValidActorOutcomes(
                    phase: phase, operation: operation)
                #expect(validActorOutcomes.count == AuthorityActor.validCases.count)

                for actor in AuthorityActor.allCases {
                    rowCount += 1
                    let expected = actor.validIndex.map { validActorOutcomes[$0] }
                        ?? .rejected(.notSeated)
                    let label = "\(phase.label) / \(operation.label) / \(actor.label)"
                    let original = source
                    let originalWire = try GamePayload.encode(source)
                    let result = source.committing(
                        operation.value,
                        actorID: actor.rawID,
                        now: operation.date(relativeTo: fixtures.startedAt)
                    )

                    #expect(observed(result) == expected, Comment(rawValue: label))
                    try expectSourceUnchanged(
                        source, original: original, originalWire: originalWire, label: label)
                    expectAppliedSemantics(
                        result,
                        expected: expected,
                        source: source,
                        operation: operation,
                        actorID: actor.canonicalID,
                        label: label
                    )
                }
            }
        }

        #expect(rowCount == 256)
    }

    @Test("revision preflight gates every otherwise-authorized operation")
    func revisionGateMatrix() throws {
        let fixtures = try AuthorityFixtures()
        var rowCount = 0

        for operation in AuthorityOperation.allCases {
            let scenario = authorizedScenario(for: operation, fixtures: fixtures)
            for condition in RevisionCondition.allCases {
                rowCount += 1
                let latest = try condition.latest(for: scenario.source.revision)
                let label = "\(operation.label) / \(condition.label)"
                let original = scenario.source
                let originalWire = try GamePayload.encode(scenario.source)

                #expect(
                    scenario.source.revision.disposition(comparedTo: latest)
                        == condition.disposition,
                    Comment(rawValue: "precondition: \(label)")
                )

                let result = scenario.source.committing(
                    operation.value,
                    actorID: scenario.actorID,
                    latestRevision: latest,
                    now: operation.date(relativeTo: fixtures.startedAt)
                )
                let expected: ExpectedOutcome = condition.admitsCommit
                    ? .applied(operation.resultPhase)
                    : .rejected(.stale)

                #expect(observed(result) == expected, Comment(rawValue: label))
                try expectSourceUnchanged(
                    scenario.source,
                    original: original,
                    originalWire: originalWire,
                    label: label
                )
                expectAppliedSemantics(
                    result,
                    expected: expected,
                    source: scenario.source,
                    operation: operation,
                    actorID: scenario.actorID,
                    label: label
                )
            }
        }

        #expect(rowCount == 40)
    }

    @Test("invalid local actor identity wins before revision preflight")
    func invalidIdentityPrecedesRevisionGate() throws {
        let fixtures = try AuthorityFixtures()
        let source = fixtures.live
        let stale = TableRevision(
            tableID: source.revision.tableID,
            phase: source.revision.phase,
            version: source.revision.version + 1
        )
        #expect(source.revision.disposition(comparedTo: stale) == .stale)

        for actor in AuthorityActor.invalidCases {
            let originalWire = try GamePayload.encode(source)
            let result = source.committing(
                .gameAction(.fold), actorID: actor.rawID, latestRevision: stale,
                now: fixtures.startedAt.addingTimeInterval(1)
            )
            #expect(
                result == .rejected(.notSeated),
                Comment(rawValue: "invalid actor before stale revision: \(actor.label)")
            )
            try expectSourceUnchanged(
                source, original: source, originalWire: originalWire, label: actor.label)
        }
    }

    @Test("authorized mutations fail closed at monotonic counter exhaustion")
    func counterExhaustionMatrix() throws {
        let fixtures = try AuthorityFixtures()
        let rows = exhaustedCounterRows(fixtures: fixtures)

        for row in rows {
            let original = row.source
            let originalWire = try GamePayload.encode(row.source)
            let result = row.source.committing(
                row.operation.value,
                actorID: row.actorID,
                now: row.operation.date(relativeTo: fixtures.startedAt)
            )

            #expect(observed(result) == row.expected, Comment(rawValue: row.label))
            try expectSourceUnchanged(
                row.source,
                original: original,
                originalWire: originalWire,
                label: row.label
            )
        }

        #expect(rows.count == 11)
    }
}

private enum AuthorityPhase: CaseIterable {
    case lobby
    case live
    case completed
    case gameOver

    var label: String {
        switch self {
        case .lobby: "lobby"
        case .live: "live hand"
        case .completed: "completed hand"
        case .gameOver: "game over"
        }
    }
}

private enum AuthorityOperation: CaseIterable {
    case joinLobby
    case startGame
    case leaveLobby
    case gameAction
    case resolveTimeout
    case joinGame
    case leaveGame
    case dealNextHand

    var label: String {
        switch self {
        case .joinLobby: "join lobby"
        case .startGame: "start game"
        case .leaveLobby: "leave lobby"
        case .gameAction: "game action"
        case .resolveTimeout: "resolve timeout"
        case .joinGame: "join game"
        case .leaveGame: "leave game"
        case .dealNextHand: "deal next hand"
        }
    }

    var value: TableOperation {
        switch self {
        case .joinLobby: .joinLobby(name: "Joined", avatar: "J")
        case .startGame: .startGame(seed: 0xA11CE, turnDuration: 30)
        case .leaveLobby: .leaveLobby
        case .gameAction: .gameAction(.fold)
        case .resolveTimeout: .resolveTimeout
        case .joinGame: .joinGame(name: "Joined", avatar: "J", startingStack: 777)
        case .leaveGame: .leaveGame
        case .dealNextHand: .dealNextHand(seed: 0xBEEF)
        }
    }

    var resultPhase: TableRevision.Phase {
        switch self {
        case .joinLobby, .leaveLobby: .lobby
        default: .game
        }
    }

    func date(relativeTo start: Date) -> Date {
        start.addingTimeInterval(self == .resolveTimeout ? 31 : 1)
    }
}

private enum AuthorityActor: CaseIterable {
    case current
    case nonActor
    case left
    case eliminated
    case unknown
    case blank
    case control
    case oversized

    static let validCases: [AuthorityActor] = [
        .current, .nonActor, .left, .eliminated, .unknown,
    ]
    static let invalidCases: [AuthorityActor] = [.blank, .control, .oversized]

    var label: String {
        switch self {
        case .current: "seated current actor (trimmed)"
        case .nonActor: "seated nonactor"
        case .left: "left actor"
        case .eliminated: "eliminated actor"
        case .unknown: "unknown actor"
        case .blank: "blank actor"
        case .control: "control-character actor"
        case .oversized: "oversized actor"
        }
    }

    var rawID: String {
        switch self {
        case .current: "  current  "
        case .nonActor: "other"
        case .left: "left"
        case .eliminated: "eliminated"
        case .unknown: "unknown"
        case .blank: " \n\t "
        case .control: "actor\u{0007}"
        case .oversized: String(repeating: "x", count: Identity.maximumUTF8Length + 1)
        }
    }

    var canonicalID: String {
        switch self {
        case .current: "current"
        default: rawID
        }
    }

    var validIndex: Int? { Self.validCases.firstIndex(of: self) }
}

private enum ExpectedOutcome: Equatable {
    case applied(TableRevision.Phase)
    case unchanged
    case rejected(TableOperationRejection)
}

private func observed(_ result: TableOperationResult) -> ExpectedOutcome {
    switch result {
    case .applied(let message): .applied(message.revision.phase)
    case .unchanged: .unchanged
    case .rejected(let rejection): .rejected(rejection)
    }
}

/// Outcomes are ordered as current actor, seated nonactor, left, eliminated, unknown.
private func expectedValidActorOutcomes(
    phase: AuthorityPhase, operation: AuthorityOperation
) -> [ExpectedOutcome] {
    let wrongPhase = Array(repeating: ExpectedOutcome.rejected(.wrongPhase), count: 5)
    let gameOver = Array(repeating: ExpectedOutcome.rejected(.gameOver), count: 5)

    switch phase {
    case .lobby:
        switch operation {
        case .joinLobby:
            return [.unchanged, .unchanged, .applied(.lobby), .applied(.lobby), .applied(.lobby)]
        case .startGame:
            return [.applied(.game), .applied(.game), .rejected(.notSeated),
                    .rejected(.notSeated), .rejected(.notSeated)]
        case .leaveLobby:
            return [.applied(.lobby), .applied(.lobby), .rejected(.notSeated),
                    .rejected(.notSeated), .rejected(.notSeated)]
        default:
            return wrongPhase
        }

    case .live:
        switch operation {
        case .joinLobby, .startGame, .leaveLobby:
            return wrongPhase
        case .gameAction:
            return [.applied(.game), .rejected(.notActorTurn), .rejected(.notActorTurn),
                    .rejected(.notActorTurn), .rejected(.notSeated)]
        case .resolveTimeout:
            return [.applied(.game), .applied(.game), .rejected(.notSeated),
                    .applied(.game), .rejected(.notSeated)]
        case .joinGame:
            return [.unchanged, .unchanged, .applied(.game), .unchanged, .applied(.game)]
        case .leaveGame:
            return [.applied(.game), .applied(.game), .rejected(.notSeated),
                    .applied(.game), .rejected(.notSeated)]
        case .dealNextHand:
            return [.rejected(.illegalAction), .rejected(.illegalAction),
                    .rejected(.notSeated), .rejected(.notSeated), .rejected(.notSeated)]
        }

    case .completed:
        switch operation {
        case .joinLobby, .startGame, .leaveLobby:
            return wrongPhase
        case .gameAction:
            return [.rejected(.notActorTurn), .rejected(.notActorTurn),
                    .rejected(.notActorTurn), .rejected(.notActorTurn),
                    .rejected(.notSeated)]
        case .resolveTimeout:
            return [.rejected(.illegalAction), .rejected(.illegalAction),
                    .rejected(.notSeated), .rejected(.illegalAction),
                    .rejected(.notSeated)]
        case .joinGame:
            return [.unchanged, .unchanged, .applied(.game), .applied(.game), .applied(.game)]
        case .leaveGame:
            return [.applied(.game), .applied(.game), .rejected(.notSeated),
                    .applied(.game), .rejected(.notSeated)]
        case .dealNextHand:
            return [.applied(.game), .applied(.game), .rejected(.notSeated),
                    .rejected(.notSeated), .rejected(.notSeated)]
        }

    case .gameOver:
        switch operation {
        case .joinLobby, .startGame, .leaveLobby: return wrongPhase
        default: return gameOver
        }
    }
}

private struct AuthorityFixtures {
    let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
    let lobby: TableMessage
    let live: TableMessage
    let completed: TableMessage
    let gameOver: TableMessage

    init() throws {
        lobby = .lobby(
            Lobby(tableID: "authority-table")
                .fixtureSeat(id: "current", name: "Current", avatar: "C")
                .fixtureSeat(id: "other", name: "Other", avatar: "O")
        )

        var departed = Player(id: "left", name: "Left", avatar: "L", stack: 500)
        departed.hasLeft = true
        let eliminated = Player(
            id: "eliminated", name: "Eliminated", avatar: "E", stack: 0)
        let liveState = GameState.startHand(
            players: [
                Player(id: "current", name: "Current", avatar: "C", stack: 1_000),
                Player(id: "other", name: "Other", avatar: "O", stack: 1_000),
                departed,
                eliminated,
            ],
            dealerIndex: 0,
            smallBlind: 10,
            bigBlind: 20,
            seed: 0xCAFE,
            handNumber: 1,
            tableID: "authority-table",
            turnDuration: 30,
            now: startedAt
        )
        guard liveState.currentPlayer?.id == "current" else {
            throw AuthorityFixtureError.unexpectedCurrentActor
        }
        live = .game(liveState)

        var completedState = liveState
        guard completedState.applyCurrent(
            .fold, by: 0, now: startedAt.addingTimeInterval(1)) else {
            throw AuthorityFixtureError.couldNotCompleteHand
        }
        guard completedState.isHandComplete, !completedState.isGameOver else {
            throw AuthorityFixtureError.unexpectedCompletedPhase
        }
        completed = .game(completedState)

        var gameOverState = liveState
        guard gameOverState.playerLeaves(
            id: "other", now: startedAt.addingTimeInterval(1)),
              gameOverState.isGameOver else {
            throw AuthorityFixtureError.couldNotEndGame
        }
        gameOver = .game(gameOverState)
    }

    func message(for phase: AuthorityPhase) -> TableMessage {
        switch phase {
        case .lobby: lobby
        case .live: live
        case .completed: completed
        case .gameOver: gameOver
        }
    }
}

private enum AuthorityFixtureError: Error {
    case unexpectedCurrentActor
    case couldNotCompleteHand
    case unexpectedCompletedPhase
    case couldNotEndGame
    case unreadableRevisionBranch
    case extremeRevisionBranch
}

private struct AuthorizedScenario {
    let source: TableMessage
    let actorID: String
}

private func authorizedScenario(
    for operation: AuthorityOperation, fixtures: AuthorityFixtures
) -> AuthorizedScenario {
    switch operation {
    case .joinLobby:
        AuthorizedScenario(source: fixtures.lobby, actorID: "unknown")
    case .startGame, .leaveLobby:
        AuthorizedScenario(source: fixtures.lobby, actorID: "current")
    case .gameAction, .resolveTimeout, .leaveGame:
        AuthorizedScenario(source: fixtures.live, actorID: "current")
    case .joinGame:
        AuthorizedScenario(source: fixtures.live, actorID: "unknown")
    case .dealNextHand:
        AuthorizedScenario(source: fixtures.completed, actorID: "current")
    }
}

private enum RevisionCondition: CaseIterable {
    case duplicate
    case preferredConflict
    case newerLatest
    case losingConflict
    case crossTable

    var label: String {
        switch self {
        case .duplicate: "duplicate latest"
        case .preferredConflict: "accepted preferred conflict"
        case .newerLatest: "stale against newer latest"
        case .losingConflict: "rejected losing conflict"
        case .crossTable: "cross-table latest"
        }
    }

    var disposition: TableRevisionDisposition {
        switch self {
        case .duplicate: .duplicate
        case .preferredConflict: .conflicting(preferred: true)
        case .newerLatest: .stale
        case .losingConflict: .conflicting(preferred: false)
        case .crossTable: .differentTable
        }
    }

    var admitsCommit: Bool {
        switch self {
        case .duplicate, .preferredConflict: true
        default: false
        }
    }

    func latest(for source: TableRevision) throws -> TableRevision {
        switch self {
        case .duplicate:
            source
        case .preferredConflict:
            TableRevision(
                tableID: source.tableID,
                phase: source.phase,
                version: source.version,
                branch: try adjacentBranch(to: source, direction: .lower)
            )
        case .newerLatest:
            TableRevision(
                tableID: source.tableID,
                phase: source.phase,
                version: source.version + 1
            )
        case .losingConflict:
            TableRevision(
                tableID: source.tableID,
                phase: source.phase,
                version: source.version,
                branch: try adjacentBranch(to: source, direction: .higher)
            )
        case .crossTable:
            TableRevision(
                tableID: "foreign-authority-table",
                phase: source.phase,
                version: source.version
            )
        }
    }
}

private enum BranchDirection { case lower, higher }

private func adjacentBranch(
    to revision: TableRevision, direction: BranchDirection
) throws -> String {
    let data = try JSONEncoder().encode(revision)
    guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let branch = object["branch"] as? String,
          branch.utf8.count == 32 else {
        throw AuthorityFixtureError.unreadableRevisionBranch
    }
    let candidate = String(repeating: direction == .lower ? "0" : "f", count: 32)
    guard candidate != branch else { throw AuthorityFixtureError.extremeRevisionBranch }
    return candidate
}

private struct ExhaustedCounterRow {
    let label: String
    let source: TableMessage
    let operation: AuthorityOperation
    let actorID: String
    let expected: ExpectedOutcome
}

private func exhaustedCounterRows(fixtures: AuthorityFixtures) -> [ExhaustedCounterRow] {
    guard case .lobby(var lobby) = fixtures.lobby,
          case .game(var live) = fixtures.live,
          case .game(var completed) = fixtures.completed else { return [] }
    lobby.version = Int.max
    live.version = Int.max
    completed.version = Int.max

    var exhaustedHandNumber = completed
    exhaustedHandNumber.version = 10
    exhaustedHandNumber.handNumber = Int.max

    let exhaustedLobby = TableMessage.lobby(lobby)
    let exhaustedLive = TableMessage.game(live)
    let exhaustedCompleted = TableMessage.game(completed)

    return [
        ExhaustedCounterRow(
            label: "lobby join at version max", source: exhaustedLobby,
            operation: .joinLobby, actorID: "unknown", expected: .rejected(.illegalAction)),
        ExhaustedCounterRow(
            label: "lobby start at version max", source: exhaustedLobby,
            operation: .startGame, actorID: "current", expected: .rejected(.illegalAction)),
        ExhaustedCounterRow(
            label: "lobby leave at version max", source: exhaustedLobby,
            operation: .leaveLobby, actorID: "current", expected: .rejected(.illegalAction)),
        ExhaustedCounterRow(
            label: "lobby idempotent join at version max", source: exhaustedLobby,
            operation: .joinLobby, actorID: "current", expected: .unchanged),
        ExhaustedCounterRow(
            label: "game action at version max", source: exhaustedLive,
            operation: .gameAction, actorID: "current", expected: .rejected(.illegalAction)),
        ExhaustedCounterRow(
            label: "timeout resolution at version max", source: exhaustedLive,
            operation: .resolveTimeout, actorID: "current", expected: .rejected(.illegalAction)),
        ExhaustedCounterRow(
            label: "new game join at version max", source: exhaustedLive,
            operation: .joinGame, actorID: "unknown", expected: .rejected(.illegalAction)),
        ExhaustedCounterRow(
            label: "idempotent game join at version max", source: exhaustedLive,
            operation: .joinGame, actorID: "current", expected: .unchanged),
        ExhaustedCounterRow(
            label: "game leave at version max", source: exhaustedLive,
            operation: .leaveGame, actorID: "current", expected: .rejected(.illegalAction)),
        ExhaustedCounterRow(
            label: "next hand at version max", source: exhaustedCompleted,
            operation: .dealNextHand, actorID: "current", expected: .rejected(.gameOver)),
        ExhaustedCounterRow(
            label: "next hand at hand-number max", source: .game(exhaustedHandNumber),
            operation: .dealNextHand, actorID: "current", expected: .rejected(.gameOver)),
    ]
}

private func expectSourceUnchanged(
    _ source: TableMessage,
    original: TableMessage,
    originalWire: String,
    label: String
) throws {
    #expect(source == original, Comment(rawValue: "source value: \(label)"))
    #expect(source.revision == original.revision, Comment(rawValue: "source revision: \(label)"))
    #expect(
        try GamePayload.encode(source) == originalWire,
        Comment(rawValue: "source wire payload: \(label)")
    )
}

private func expectAppliedSemantics(
    _ result: TableOperationResult,
    expected: ExpectedOutcome,
    source: TableMessage,
    operation: AuthorityOperation,
    actorID: String,
    label: String
) {
    guard case .applied(let next) = result else { return }
    #expect(expected == .applied(operation.resultPhase), Comment(rawValue: label))
    #expect(next != source, Comment(rawValue: "changed successor: \(label)"))
    #expect(next.revision.tableID == source.revision.tableID, Comment(rawValue: label))
    #expect(source.revision.isOlder(than: next.revision), Comment(rawValue: label))

    switch (operation, next) {
    case (.joinLobby, .lobby(let lobby)):
        #expect(lobby.seat(id: actorID) != nil, Comment(rawValue: label))
    case (.startGame, .game(let state)):
        #expect(state.players.contains { $0.id == actorID }, Comment(rawValue: label))
    case (.leaveLobby, .lobby(let lobby)):
        #expect(lobby.seat(id: actorID) == nil, Comment(rawValue: label))
    case (.gameAction, .game(let state)):
        #expect(state.player(id: "current")?.lastAction == .fold, Comment(rawValue: label))
    case (.resolveTimeout, .game(let state)):
        #expect(state.player(id: "current")?.lastAction == .fold, Comment(rawValue: label))
    case (.joinGame, .game(let state)):
        #expect(state.player(id: actorID)?.hasLeft == false, Comment(rawValue: label))
        #expect(state.player(id: actorID)?.name == "Joined", Comment(rawValue: label))
    case (.leaveGame, .game(let state)):
        #expect(state.player(id: actorID)?.hasLeft == true, Comment(rawValue: label))
    case (.dealNextHand, .game(let state)):
        guard case .game(let previous) = source else {
            Issue.record("next-hand source was not a game: \(label)")
            return
        }
        #expect(state.handNumber == previous.handNumber + 1, Comment(rawValue: label))
        #expect(state.player(id: actorID) != nil, Comment(rawValue: label))
    default:
        Issue.record("unexpected applied phase: \(label)")
    }
}
