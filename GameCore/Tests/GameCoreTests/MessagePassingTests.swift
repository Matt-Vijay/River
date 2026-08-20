import Testing

@testable import GameCore

@Suite("Message passing")
struct MessagePassingTests {
  @Test("heads-up hand completes through encoded payloads")
  func headsUpHand() throws {
    let final = try playFullHandOverTheWire(playerCount: 2, seed: 1)
    #expect(final.isHandComplete)
    #expect(final.currentToAct == nil)
    #expect(final.board.count == 5)
    #expect(final.players.reduce(0) { $0 + $1.stack } == 2000)
    #expect(try #require(final.results).allSatisfy { $0.handName != nil })
  }

  @Test("three-way all-in preserves side pots and membership through the wire")
  func sidePotsAndMembership() throws {
    var wire = try encodedGame(
      GameState.startHand(
        players: [
          Player(id: "p0", name: "p0", avatar: "🙂", stack: 100),
          Player(id: "p1", name: "p1", avatar: "🙂", stack: 50),
          Player(id: "p2", name: "p2", avatar: "🙂", stack: 200),
        ], dealerIndex: 0, smallBlind: 10, bigBlind: 20, seed: 5, handNumber: 1)
    )

    func act(_ make: (inout GameState) -> Void) throws {
      var state = try decodedGame(from: wire)
      make(&state)
      wire = try encodedGame(state)
    }

    try act { $0.apply(.raise(to: 100), by: 0) }
    try act { $0.apply(.call, by: 1) }
    try act { state in
      let didLeave = state.playerLeaves(id: "p1")
      #expect(didLeave)
      #expect(state.player(id: "p1")?.status == .allIn)
    }
    try act { state in
      state.rejoinOrAddSittingOutPlayer(
        id: "p1", name: "Rejoined p1", avatar: "🂡", stack: 1_000
      )
      let rejoined = state.player(id: "p1")
      #expect(rejoined?.hasLeft == false)
      #expect(rejoined?.status == .allIn)
      #expect(rejoined?.stack == 0)
      #expect(rejoined?.bet == 50)
      #expect(rejoined?.committed == 50)
    }
    try act { $0.apply(.call, by: 2) }

    let final = try decodedGame(from: wire)
    let results = try #require(final.results)
    #expect(final.players.reduce(0) { $0 + $1.stack } == 350)
    #expect(final.player(id: "p1")?.hasLeft == false)
    #expect(final.player(id: "p1")?.status == .allIn)
    let p1Won = results.first { $0.playerID == "p1" }?.amountWon ?? 0
    #expect(p1Won == 0 || p1Won == 150)
  }
}
