import Foundation
import Testing

@testable import GameCore

@Suite("Game action operations")
struct GameActionOperationTests {
  @Test("game action preflight rejects locally stale selected messages")
  func gameActionPreflightRejectsLocallyStaleSelectedMessages() {
    let message = headsUpTableMessage()
    let latest = TableRevision(
      tableID: message.revision.tableID,
      phase: message.revision.phase,
      version: message.revision.version + 1)
    #expect(
      message.committing(
        .gameAction(.fold), actorID: "a", latestRevision: latest)
        == .rejected(.stale))
  }

  @Test("game action applies only for the player whose turn it is")
  func gameActionRequiresActorTurn() {
    let message = headsUpTableMessage()
    #expect(
      message.committing(.gameAction(.fold), actorID: "b")
        == .rejected(.notActorTurn))
  }

  @Test("illegal game action is rejected")
  func illegalGameActionRejected() {
    let message = headsUpTableMessage()
    #expect(
      message.committing(.gameAction(.check), actorID: "a")
        == .rejected(.illegalAction))
  }

  @Test("game actions cannot mutate a finished game")
  func gameActionCannotMutateFinishedGame() throws {
    let message = headsUpTableMessage()
    guard case .applied(.game(let finishedState)) = message.committing(
      .leaveGame, actorID: "b")
    else {
      Issue.record("expected first action to finish the game")
      return
    }
    let finishedMessage = TableMessage.game(finishedState)

    #expect(
      finishedMessage.committing(.gameAction(.call), actorID: "a")
        == .rejected(.gameOver))
  }

  @Test("expired game actions are rejected until timeout resolution is explicit")
  func expiredGameActionRequiresExplicitTimeoutResolution() throws {
    let start = Date()
    let state = GameState.startHand(
      players: [
        Player(id: "a", name: "Alice", avatar: "A", stack: 1000),
        Player(id: "b", name: "Bob", avatar: "B", stack: 1000),
        Player(id: "c", name: "Cara", avatar: "C", stack: 1000),
      ], dealerIndex: 0, smallBlind: 10, bigBlind: 20,
      seed: 1, handNumber: 1, tableID: "table-123",
      turnDuration: 30, now: start)
    let message = TableMessage.game(state)
    let expired = start.addingTimeInterval(45)

    #expect(
      message.committing(
        .gameAction(.call), actorID: "b", now: expired)
        == .rejected(.illegalAction))

    guard case .applied(.game(let next)) = message.committing(
      .resolveTimeout, actorID: "b", now: expired)
    else {
      Issue.record("expected explicit timeout resolution")
      return
    }

    #expect(next.players[0].status == .folded)
    #expect(next.players[1].lastAction == nil)
  }

  @Test("timeout resolution commits hand completion")
  func timeoutResolutionCommitsHandCompletion() throws {
    let start = Date()
    let state = GameState.startHand(
      players: [
        Player(id: "a", name: "Alice", avatar: "A", stack: 1000),
        Player(id: "b", name: "Bob", avatar: "B", stack: 1000),
      ], dealerIndex: 0, smallBlind: 10, bigBlind: 20,
      seed: 1, handNumber: 1, tableID: "table-123",
      turnDuration: 30, now: start)
    let message = TableMessage.game(state)
    guard
      case .applied(.game(let next)) = message.committing(
        .resolveTimeout, actorID: "b",
        now: start.addingTimeInterval(45)
      )
    else {
      Issue.record("expected timeout-completed hand to be sent")
      return
    }

    let resent = try decodedGame(from: try encodedGame(next))
    #expect(resent.isHandComplete)
    #expect(resent.players[0].status == .folded)
    #expect(resent.players[1].stack == 1010)
    #expect(resent.results?.first?.playerID == "b")
  }

  @Test("committing a game action advances the state")
  func committingGameActionAdvancesState() throws {
    let message = headsUpTableMessage()

    guard
      case .applied(.game(let next)) = message.committing(
        .gameAction(.fold),
        actorID: "a"
      )
    else {
      Issue.record("Expected commit to apply")
      return
    }

    #expect(next.version > message.revision.version)
    #expect(next.results?.first?.playerID == "b")
  }

  @Test("actor identities are trimmed")
  func actorIdentitiesAreNormalized() {
    let message = headsUpTableMessage()
    guard case .applied(.game(let next)) = message.committing(
      .gameAction(.fold), actorID: "  a  ")
    else {
      Issue.record("expected padded identity to apply")
      return
    }
    #expect(next.results?.first?.playerID == "b")
  }

}
