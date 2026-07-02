import Testing
@testable import GameCore

@Suite("Side pots")
struct SidePotTests {
    private func stateWithCommitted(_ committed: [Int], statuses: [PlayerStatus]) -> GameState {
        var players = makePlayers(committed.map { _ in 0 })
        for i in players.indices {
            players[i].committed = committed[i]
            players[i].status = statuses[i]
        }
        return GameState(handNumber: 1, players: players, dealerIndex: 0,
                         smallBlind: 10, bigBlind: 20, board: [], deck: [], pot: 0,
                         street: .river, currentToAct: nil, currentBet: 0, minRaise: 20,
                         turnStartedAt: nil, turnDuration: 30, results: nil, version: 0)
    }

    @Test("unequal all-ins build a main pot and a side pot")
    func mainAndSide() {
        // A=100, B=50, C=100 committed; all contesting.
        let s = stateWithCommitted([100, 50, 100], statuses: [.allIn, .allIn, .active])
        let pots = s.buildSidePots()
        #expect(pots.count == 2)
        #expect(pots[0].amount == 150)            // 50 * 3
        #expect(Set(pots[0].eligible) == [0, 1, 2])
        #expect(pots[1].amount == 100)            // 50 * 2
        #expect(Set(pots[1].eligible) == [0, 2])
    }

    @Test("all-in 300 vs 400: short stack capped, extra 100 is its own pot")
    func cappedAllIn300vs400() {
        // The 300 all-in can win at most 300 from the opponent; the opponent's
        // extra 100 forms a side pot only they are eligible for.
        let s = stateWithCommitted([300, 400], statuses: [.allIn, .allIn])
        let pots = s.buildSidePots()
        #expect(pots.count == 2)
        #expect(pots[0].amount == 600)            // 300 matched by both
        #expect(Set(pots[0].eligible) == [0, 1])
        #expect(pots[1].amount == 100)            // uncalled remainder
        #expect(pots[1].eligible == [1])          // only the 400 player
    }

    @Test("a folded contributor funds pots but cannot win them")
    func foldedContributes() {
        // B folded after committing 50.
        let s = stateWithCommitted([100, 50, 100], statuses: [.allIn, .folded, .active])
        let pots = s.buildSidePots()
        #expect(pots[0].amount == 150)
        #expect(Set(pots[0].eligible) == [0, 2])   // B excluded though chips counted
    }

    @Test("odd-chip seat order normalizes malformed dealer index")
    func oddChipSeatOrderNormalizesMalformedDealerIndex() {
        var s = stateWithCommitted([100, 100, 100], statuses: [.allIn, .allIn, .allIn])
        s.dealerIndex = -5

        #expect(s.seatOrder(2) == 0)
        #expect(s.seatOrder(0) == 1)
        #expect(s.seatOrder(1) == 2)
    }

    @Test("a short all-in player can only win the main pot")
    func shortStackCappedWinnings() throws {
        // Drive a real 3-way all-in and confirm the short stack never wins more
        // than the main pot, and chips are conserved.
        var s = GameState.startHand(players: makePlayers([100, 50, 200]),
                                    dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                    seed: 5, handNumber: 1)
        s.apply(.raise(to: 100), by: 0)   // A shoves 100
        s.apply(.call, by: 1)             // B calls all-in for 50
        s.apply(.call, by: 2)             // C calls 100
        #expect(s.street == .showdown)
        #expect(totalChips(s) == 350)
        let results = try #require(s.results)
        let bWon = try #require(results.first { $0.playerID == "p1" }).amountWon
        #expect(bWon == 0 || bWon == 150)  // at most the main pot (50*3)
    }
}
