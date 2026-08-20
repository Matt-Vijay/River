import Testing

@testable import GameCore

@Suite("Game membership operations")
struct GameMembershipOperationTests {
  @Test("join game preserves active player identity without sitting them out")
  func joinGamePreservesActivePlayerIdentityAndStatus() {
    let message = headsUpTableMessage()
    #expect(
      message.committing(
        .joinGame(name: "Updated Alice", avatar: "A2", startingStack: 1000),
        actorID: "a")
        == .unchanged)
  }

  @Test("departed and busted players can rejoin with chips between hands")
  func departedAndBustedPlayersCanRejoinWithChipsBetweenHands() throws {
    var state = GameState.startHand(
      players: makePlayers([0, 1000, 1000]),
      dealerIndex: 1,
      smallBlind: 10,
      bigBlind: 20,
      seed: 1,
      handNumber: 1,
      tableID: "table-123")
    state.players[0].hasLeft = true
    state.players[0].status = .sittingOut
    let message = TableMessage.game(state)
    guard case .applied(.game(let next)) = message.committing(
      .joinGame(name: "Updated Player", avatar: "🂡", startingStack: 1000),
      actorID: "p0"),
      let rejoined = next.player(id: "p0")
    else {
      Issue.record("expected departed player to rejoin")
      return
    }

    #expect(!rejoined.hasLeft)
    #expect(rejoined.status == .sittingOut)
    #expect(rejoined.stack == 1000)
    #expect(rejoined.name == "Updated Player")
    #expect(rejoined.avatar == "🂡")

    state.results = [
      HandResult(playerID: "p1", amountWon: 30, handName: nil, bestFive: nil)
    ]
    state.players[0].hasLeft = false
    state.players[0].status = .eliminated
    state.players[0].stack = 0

    let rebuyMessage = TableMessage.game(state)
    guard case .applied(.game(let reboughtState)) = rebuyMessage.committing(
      .joinGame(name: "Updated Again", avatar: "A", startingStack: 800),
      actorID: "p0"),
      let rebought = reboughtState.player(id: "p0")
    else {
      Issue.record("expected busted player to rebuy")
      return
    }
    #expect(rebought.status == .sittingOut)
    #expect(rebought.stack == 800)
  }

  @Test("membership cannot change after the game has an overall winner")
  func membershipCannotChangeAfterGameOver() throws {
    var state = GameState.startHand(
      players: makePlayers([1000, 1000]),
      dealerIndex: 0,
      smallBlind: 10,
      bigBlind: 20,
      seed: 1,
      handNumber: 1)
    let didLeave = state.playerLeaves(id: "p1")
    let message = TableMessage.game(state)
    let finished = state
    #expect(didLeave)
    #expect(state.overallWinner?.id == "p0")
    #expect(
      message.committing(
        .joinGame(name: "Rook", avatar: "R", startingStack: 1000),
        actorID: "observer")
        == .rejected(.gameOver))
    #expect(message.committing(.leaveGame, actorID: "p0") == .rejected(.gameOver))
    let winnerCouldLeave = state.playerLeaves(id: "p0")
    #expect(!winnerCouldLeave)
    #expect(state == finished)
  }

  @Test("non-current leave advances the game revision")
  func nonCurrentLeaveAdvancesRevision() {
    let message = headsUpTableMessage()
    guard case .applied(.game(let next)) = message.committing(
      .leaveGame, actorID: "b"),
      let bob = next.player(id: "b")
    else {
      Issue.record("expected applied game")
      return
    }
    #expect(bob.hasLeft)
    #expect(next.version == message.revision.version + 1)
    #expect(next.results?.first?.playerID == "a")
  }

  @Test("an already-left player cannot leave again")
  func alreadyLeftPlayerCannotLeaveAgain() {
    let message = TableMessage.game(GameState.startHand(
      players: [
        Player(id: "a", name: "Alice", avatar: "A", stack: 1000),
        Player(id: "b", name: "Bob", avatar: "B", stack: 1000),
        Player(id: "c", name: "Cara", avatar: "C", stack: 1000),
      ], dealerIndex: 0, smallBlind: 5, bigBlind: 10,
      seed: 1, handNumber: 1, tableID: "table-123"
    ))
    guard case .applied(let departed) = message.committing(
      .leaveGame, actorID: "b"
    ) else {
      Issue.record("expected first leave to apply")
      return
    }
    #expect(
      departed.committing(.leaveGame, actorID: "b")
        == .rejected(.notSeated))
  }

  @Test("leaving a live three-player hand folds only the departing player")
  func leavingLiveThreePlayerHandContinues() throws {
    var state = GameState.startHand(
      players: makePlayers([200, 30, 100]), dealerIndex: 0,
      smallBlind: 10, bigBlind: 20, seed: 2, handNumber: 1)
    let departing = try #require(state.currentToAct)
    let didRaise = state.apply(.raise(to: 100), by: departing)
    let didLeave = state.playerLeaves(id: state.players[departing].id)
    #expect(didRaise)
    #expect(didLeave)

    #expect(state.players[departing].hasLeft)
    #expect(state.currentBet == 20)
    let next = try #require(state.currentToAct)
    #expect(state.legalActions(for: next).callAmount == 10)
    let didCall = state.apply(.call, by: next)
    #expect(didCall)
    let bigBlind = try #require(state.currentToAct)
    #expect(state.legalActions(for: bigBlind).canCheck)
    #expect(state.results == nil)
    #expect(state.playersEligibleForNextHand.count == 2)
  }

  @Test("leaving after hand completion preserves the recorded result")
  func leavingAfterCompletionOnlyMarksPlayerLeft() throws {
    var state = GameState.startHand(
      players: makePlayers([1000, 1000]), dealerIndex: 0,
      smallBlind: 10, bigBlind: 20, seed: 1, handNumber: 1)
    let didFold = state.apply(.fold, by: 0)
    #expect(didFold)
    let winner = try #require(state.playerIndex(id: "p1"))
    let result = state.results
    let status = state.players[winner].status
    let lastAction = state.players[winner].lastAction

    let didLeave = state.playerLeaves(id: "p1")
    #expect(didLeave)
    #expect(state.players[winner].hasLeft)
    #expect(state.players[winner].status == status)
    #expect(state.players[winner].lastAction == lastAction)
    #expect(state.results == result)
  }
}
