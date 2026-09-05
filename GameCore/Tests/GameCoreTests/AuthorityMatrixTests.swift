import Foundation
import Testing

@testable import GameCore

@Suite("Table operation authority matrix")
struct AuthorityMatrixTests {
    @Test("all operations respect phase and actor permissions")
    func operationPhaseActorMatrix() throws {
        let fixture = try AuthorityFixtures()
        let wrongPhase = Array(repeating: Outcome.rejected(.wrongPhase), count: 5)
        let gameOver = Array(repeating: Outcome.rejected(.gameOver), count: 5)
        // Columns: current actor, other seat, departed seat, busted seat, unknown actor.
        // Rows follow operations below; invalid identities are checked separately.
        let phases: [(String, TableMessage, [[Outcome]])] = [
            ("lobby", .lobby(fixture.lobby), [
                [.unchanged, .unchanged, .applied, .applied, .applied],
                [.applied, .applied, .rejected(.notSeated), .rejected(.notSeated), .rejected(.notSeated)],
                [.applied, .applied, .rejected(.notSeated), .rejected(.notSeated), .rejected(.notSeated)],
                wrongPhase, wrongPhase, wrongPhase, wrongPhase, wrongPhase,
            ]),
            ("live", .game(fixture.live), [
                wrongPhase, wrongPhase, wrongPhase,
                [.applied, .rejected(.notActorTurn), .rejected(.notActorTurn),
                 .rejected(.notActorTurn), .rejected(.notSeated)],
                [.applied, .applied, .rejected(.notSeated), .applied, .rejected(.notSeated)],
                [.unchanged, .unchanged, .applied, .unchanged, .applied],
                [.applied, .applied, .rejected(.notSeated), .applied, .rejected(.notSeated)],
                [.rejected(.illegalAction), .rejected(.illegalAction), .rejected(.notSeated),
                 .rejected(.notSeated), .rejected(.notSeated)],
            ]),
            ("completed", .game(fixture.completed), [
                wrongPhase, wrongPhase, wrongPhase,
                [.rejected(.notActorTurn), .rejected(.notActorTurn), .rejected(.notActorTurn),
                 .rejected(.notActorTurn), .rejected(.notSeated)],
                [.rejected(.illegalAction), .rejected(.illegalAction), .rejected(.notSeated),
                 .rejected(.illegalAction), .rejected(.notSeated)],
                [.unchanged, .unchanged, .applied, .applied, .applied],
                [.applied, .applied, .rejected(.notSeated), .applied, .rejected(.notSeated)],
                [.applied, .applied, .rejected(.notSeated), .rejected(.notSeated), .rejected(.notSeated)],
            ]),
            ("game over", .game(fixture.gameOver), [
                wrongPhase, wrongPhase, wrongPhase, gameOver, gameOver, gameOver, gameOver, gameOver,
            ]),
        ]
        let actors = ["  current  ", "other", "left", "eliminated", "unknown"]
        for (phase, source, rows) in phases {
            for (index, operation) in operations.enumerated() {
                for (actorIndex, actorID) in actors.enumerated() {
                    let result = source.committing(operation, actorID: actorID, now: date(for: operation))
                    #expect(Outcome(result) == rows[index][actorIndex], "\(phase) / \(operation) / \(actorID)")
                    expectAppliedSemantics(result, source: source, operation: operation,
                                           actorID: actorID.trimmingCharacters(in: .whitespaces))
                }
                for actorID in invalidActors {
                    #expect(source.committing(operation, actorID: actorID, now: date(for: operation))
                            == .rejected(.notSeated))
                }
            }
        }
    }

    @Test("revision preflight gates every otherwise-authorized operation")
    func revisionGateMatrix() throws {
        let fixture = try AuthorityFixtures()
        let scenarios: [(TableMessage, String)] = [
            (.lobby(fixture.lobby), "unknown"),
            (.lobby(fixture.lobby), "current"),
            (.lobby(fixture.lobby), "current"),
            (.game(fixture.live), "current"),
            (.game(fixture.live), "current"),
            (.game(fixture.live), "unknown"),
            (.game(fixture.live), "current"),
            (.game(fixture.completed), "current"),
        ]
        let low = String(repeating: "0", count: 32)
        let high = String(repeating: "f", count: 32)
        for (operation, (source, actorID)) in zip(operations, scenarios) {
            let revision = source.revision
            #expect(revision.branch > low && revision.branch < high)
            let cases: [(TableRevision, Bool)] = [
                (revision, true),
                (TableRevision(tableID: revision.tableID, phase: revision.phase,
                               version: revision.version, branch: low), true),
                (TableRevision(tableID: revision.tableID, phase: revision.phase,
                               version: revision.version + 1), false),
                (TableRevision(tableID: revision.tableID, phase: revision.phase,
                               version: revision.version, branch: high), false),
                (TableRevision(tableID: "foreign", phase: revision.phase,
                               version: revision.version), false),
            ]
            for (latest, admitted) in cases {
                let result = source.committing(operation, actorID: actorID,
                                               latestRevision: latest, now: date(for: operation))
                #expect(Outcome(result) == (admitted ? .applied : .rejected(.stale)), "\(operation)")
                expectAppliedSemantics(result, source: source, operation: operation, actorID: actorID)
            }
        }
    }

    @Test("invalid local identity is rejected before revision preflight")
    func invalidIdentityPrecedesRevisionGate() throws {
        let source = TableMessage.game(try AuthorityFixtures().live)
        let stale = TableRevision(tableID: source.revision.tableID, phase: .game, version: 1)
        for actorID in invalidActors {
            #expect(source.committing(.gameAction(.fold), actorID: actorID, latestRevision: stale)
                    == .rejected(.notSeated))
        }
    }

    @Test("counter exhaustion rejects mutations but permits idempotent joins")
    func counterExhaustionMatrix() throws {
        var fixture = try AuthorityFixtures()
        fixture.lobby.version = Int.max
        fixture.live.version = Int.max
        fixture.completed.version = Int.max
        var handLimit = fixture.completed
        handLimit.version = 10
        handLimit.handNumber = Int.max
        let cases: [(TableMessage, TableOperation, String, Outcome)] = [
            (.lobby(fixture.lobby), joinLobby, "unknown", .rejected(.illegalAction)),
            (.lobby(fixture.lobby), startGame, "current", .rejected(.illegalAction)),
            (.lobby(fixture.lobby), .leaveLobby, "current", .rejected(.illegalAction)),
            (.lobby(fixture.lobby), joinLobby, "current", .unchanged),
            (.game(fixture.live), .gameAction(.fold), "current", .rejected(.illegalAction)),
            (.game(fixture.live), .resolveTimeout, "current", .rejected(.illegalAction)),
            (.game(fixture.live), joinGame, "unknown", .rejected(.illegalAction)),
            (.game(fixture.live), joinGame, "current", .unchanged),
            (.game(fixture.live), .leaveGame, "current", .rejected(.illegalAction)),
            (.game(fixture.completed), nextHand, "current", .rejected(.gameOver)),
            (.game(handLimit), nextHand, "current", .rejected(.gameOver)),
        ]
        for (source, operation, actorID, expected) in cases {
            #expect(Outcome(source.committing(operation, actorID: actorID, now: date(for: operation)))
                    == expected, "\(operation)")
        }
    }
}

private let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
private let joinLobby = TableOperation.joinLobby(name: "Joined", avatar: "J")
private let startGame = TableOperation.startGame(seed: 0xA11CE, turnDuration: 30)
private let joinGame = TableOperation.joinGame(name: "Joined", avatar: "J", startingStack: 777)
private let nextHand = TableOperation.dealNextHand(seed: 0xBEEF)
private let operations: [TableOperation] = [
    joinLobby, startGame, .leaveLobby, .gameAction(.fold),
    .resolveTimeout, joinGame, .leaveGame, nextHand,
]
private let invalidActors = [" \n\t ", "actor\u{0007}", String(repeating: "x", count: 129)]

private func date(for operation: TableOperation) -> Date {
    startedAt.addingTimeInterval(operation == .resolveTimeout ? 31 : 1)
}

private enum Outcome: Equatable {
    case applied, unchanged, rejected(TableOperationRejection)

    init(_ result: TableOperationResult) {
        self = switch result {
        case .applied: .applied
        case .unchanged: .unchanged
        case .rejected(let reason): .rejected(reason)
        }
    }
}

private struct AuthorityFixtures {
    var lobby = Lobby(tableID: "authority-table")
        .fixtureSeat(id: "current", name: "Current", avatar: "C")
        .fixtureSeat(id: "other", name: "Other", avatar: "O")
    var live: GameState
    var completed: GameState
    var gameOver: GameState

    init() throws {
        var departed = Player(id: "left", name: "Left", avatar: "L", stack: 500)
        departed.hasLeft = true
        live = GameState.startHand(players: [
            Player(id: "current", name: "Current", avatar: "C", stack: 1_000),
            Player(id: "other", name: "Other", avatar: "O", stack: 1_000),
            departed,
            Player(id: "eliminated", name: "Eliminated", avatar: "E", stack: 0),
        ], dealerIndex: 0, smallBlind: 10, bigBlind: 20, seed: 0xCAFE,
           handNumber: 1, tableID: "authority-table", turnDuration: 30, now: startedAt)
        completed = live
        gameOver = live
        try #require(live.currentPlayer?.id == "current")
        let folded = completed.applyCurrent(.fold, by: 0, now: startedAt.addingTimeInterval(1))
        try #require(folded && completed.isHandComplete && !completed.isGameOver)
        let left = gameOver.playerLeaves(id: "other", now: startedAt.addingTimeInterval(1))
        try #require(left)
        try #require(gameOver.isGameOver)
    }
}

private func expectAppliedSemantics(
    _ result: TableOperationResult, source: TableMessage, operation: TableOperation, actorID: String
) {
    guard case .applied(let next) = result else { return }
    #expect(next.revision.tableID == source.revision.tableID)
    #expect(source.revision.isOlder(than: next.revision))
    switch (operation, next) {
    case (.joinLobby, .lobby(let lobby)):
        #expect(lobby.seat(id: actorID) != nil)
    case (.startGame, .game(let state)):
        #expect(state.player(id: actorID) != nil)
    case (.leaveLobby, .lobby(let lobby)):
        #expect(lobby.seat(id: actorID) == nil)
    case (.gameAction, .game(let state)), (.resolveTimeout, .game(let state)):
        #expect(state.player(id: "current")?.lastAction == .fold)
    case (.joinGame, .game(let state)):
        #expect(state.player(id: actorID)?.hasLeft == false)
        #expect(state.player(id: actorID)?.name == "Joined")
    case (.leaveGame, .game(let state)):
        #expect(state.player(id: actorID)?.hasLeft == true)
    case (.dealNextHand, .game(let state)):
        guard case .game(let previous) = source else {
            Issue.record("next-hand source was not a game")
            return
        }
        #expect(state.handNumber == previous.handNumber + 1)
        #expect(state.player(id: actorID) != nil)
    default:
        Issue.record("wrong result phase for \(operation)")
    }
}
