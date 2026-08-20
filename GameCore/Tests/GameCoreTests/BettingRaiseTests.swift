import Testing
@testable import GameCore

@Suite("Betting raises")
struct BettingRaiseTests {
    @Test("a raise reopens the action for the other player")
    func raiseReopens() {
        var s = GameState.startHand(players: makePlayers([1000, 1000]),
                                    dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                    seed: 7, handNumber: 1)
        s.apply(.raise(to: 60), by: 0)        // dealer/SB raises to 60
        #expect(s.currentBet == 60)
        #expect(s.currentToAct == 1)          // back to BB
        #expect(s.players[1].lastActionBet == nil)
        let legal = s.legalActions(for: 1)
        #expect(legal.callAmount == 40)       // BB already has 20 in
    }

    @Test("a short all-in raise does not reopen raising")
    func shortAllInDoesNotReopenRaising() {
        var s = GameState.startHand(players: makePlayers([1000, 1000, 70]),
                                    dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                    seed: 7, handNumber: 1)

        let didRaise = s.apply(.raise(to: 60), by: 0)
        let didCall = s.apply(.call, by: 1)
        let didShortRaise = s.apply(.raise(to: 70), by: 2)
        #expect(didRaise && didCall && didShortRaise)

        let priorRaiser = s.legalActions(for: 0)
        #expect(priorRaiser.canCall)
        #expect(priorRaiser.raiseBounds == nil)
        let beforeRejectedRaise = s
        let rejectedRaise = s.apply(.raise(to: 1_000), by: 0)
        #expect(!rejectedRaise)
        #expect(s == beforeRejectedRaise)

        let didRaiserCall = s.apply(.call, by: 0)
        #expect(didRaiserCall)
        let priorCaller = s.legalActions(for: 1)
        #expect(priorCaller.canCall)
        #expect(priorCaller.raiseBounds == nil)

        var checked = GameState.startHand(players: makePlayers([1000, 10, 1000]),
                                          dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                          seed: 8, handNumber: 1)
        checked.players[0].bet = 0
        checked.players[0].lastActionBet = 0
        checked.players[0].lastAction = .check
        checked.players[1].bet = 10
        checked.players[1].stack = 0
        checked.players[1].status = .allIn
        checked.players[2].bet = 0
        checked.players[2].status = .folded
        checked.currentToAct = 0
        checked.minRaise = 20

        let priorChecker = checked.legalActions(for: 0)
        #expect(priorChecker.canCall)
        #expect(priorChecker.raiseBounds == nil)

        func stateAfterCumulativeShortRaises(finalStack: Int) -> GameState {
            var state = GameState.startHand(
                players: makePlayers([1000, 70, finalStack, 1000]),
                dealerIndex: 0,
                smallBlind: 10,
                bigBlind: 20,
                seed: 9,
                handNumber: 1
            )
            state.apply(.raise(to: 60), by: 3)
            state.apply(.call, by: 0)
            state.apply(.raise(to: 70), by: 1)
            state.apply(.raise(to: finalStack), by: 2)
            return state
        }

        let belowThreshold = stateAfterCumulativeShortRaises(finalStack: 99)
        #expect(belowThreshold.currentToAct == 3)
        #expect(belowThreshold.legalActions(for: 3).raiseBounds == nil)

        let fullThreshold = stateAfterCumulativeShortRaises(finalStack: 100)
        #expect(fullThreshold.currentToAct == 3)
        #expect(fullThreshold.legalActions(for: 3).raiseBounds != nil)
    }

    @Test("a below-minimum raise is rejected")
    func belowMinimumRaiseIsRejected() {
        var s = GameState.startHand(players: makePlayers([1000, 1000]),
                                    dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                    seed: 7, handNumber: 1)

        let before = s

        #expect(s.apply(.raise(to: 30), by: 0) == false)
        #expect(s == before)
    }

    @Test("legal actions validate the requested raise total")
    func legalActionsValidateRequestedRaiseTotal() throws {
        let s = GameState.startHand(players: makePlayers([1000, 1000]),
                                    dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                    seed: 7, handNumber: 1)
        let legal = s.legalActions(for: 0)
        let bounds = try #require(legal.raiseBounds)

        #expect(legal.allows(.raise(to: bounds.lowerBound)))
        #expect(legal.allows(.raise(to: bounds.upperBound)))
        #expect(!legal.allows(.raise(to: bounds.lowerBound - 1)))
        #expect(!legal.allows(.raise(to: bounds.upperBound + 1)))
        #expect(bounds.lowerBound != bounds.upperBound)

        let shortStack = GameState.startHand(players: makePlayers([30, 1000]),
                                             dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                             seed: 7, handNumber: 1)
        let allInOnly = shortStack.legalActions(for: 0)
        #expect(allInOnly.raiseBounds == 30...30)
        #expect(allInOnly.allows(.raise(to: 30)))

        var saturated = s
        saturated.players[0].bet = TableRules.tableMaximum
        saturated.players[0].stack = TableRules.tableMaximum
        saturated.players[0].committed = TableRules.tableMaximum
        saturated.currentToAct = 0
        saturated.minRaise = TableRules.tableMaximum

        let bounded = saturated.legalActions(for: 0)
        #expect(bounded.raiseBounds == nil)
    }

}

@Suite("Betting resolution")
struct BettingResolutionTests {
    @Test("folding hands the pot to the last player")
    func foldWins() {
        var s = GameState.startHand(players: makePlayers([1000, 1000]),
                                    dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                    seed: 1, handNumber: 1)
        s.apply(.fold, by: 0)
        #expect(s.contenders.count == 1)
        #expect(s.players[1].stack == 1010)
        #expect(s.players[0].stack == 990)
        #expect(s.results?.count == 1)
        #expect(s.results?.first?.playerID == "p1")
        #expect(totalChips(s) == 2000)
    }

}
