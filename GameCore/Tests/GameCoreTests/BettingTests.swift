import Testing

@testable import GameCore

private func expectApplication(
    _ action: PlayerAction,
    by index: Int,
    to state: inout GameState,
    expected: Bool = true
) {
    let didApply = state.apply(action, by: index)
    #expect(didApply == expected)
}

private func makeBettingState(
    _ stacks: [Int],
    dealerIndex: Int = 0,
    seed: UInt64 = 1
) -> GameState {
    GameState.startHand(
        players: makePlayers(stacks),
        dealerIndex: dealerIndex,
        smallBlind: 10,
        bigBlind: 20,
        seed: seed,
        handNumber: 1
    )
}

@Suite("Betting actions")
struct BettingTests {
    @Test("all-in and full-raise bounds meet at every stack boundary")
    func allInAndFullRaiseBoundaries() {
        let boundaries: [(stack: Int, call: Int, raise: ClosedRange<Int>?)] = [
            (15, 5, nil),
            (20, 10, nil),
            (21, 10, 21...21),
            (39, 10, 39...39),
            (40, 10, 40...40),
            (41, 10, 40...41),
            (100, 10, 40...100),
        ]

        for boundary in boundaries {
            let state = makeBettingState(
                [boundary.stack, 100], seed: UInt64(boundary.stack))
            let actual = state.legalActions(for: 0)
            #expect(state.currentToAct == 0)
            #expect(actual.canFold)
            #expect(actual.callAmount == boundary.call)
            #expect(actual.raiseBounds == boundary.raise)
        }

        var saturated = makeBettingState([100, 100])
        saturated.players[0].bet = TableRules.tableMaximum
        saturated.players[0].stack = TableRules.tableMaximum
        saturated.players[0].committed = TableRules.tableMaximum
        saturated.minRaise = TableRules.tableMaximum
        #expect(saturated.legalActions(for: 0).raiseBounds == nil)
    }

    @Test("call, check, fold, and raise permissions are exclusive and immutable on rejection")
    func actionPermissionMatrix() {
        var state = makeBettingState([100, 100], seed: 20)

        let facingBet = state.legalActions(for: 0)
        #expect(facingBet.canFold)
        #expect(facingBet.canCall)
        #expect(!facingBet.canCheck)
        #expect(facingBet.callAmount == 10)
        #expect(facingBet.raiseBounds == 40...100)
        #expect(facingBet.allows(.fold))
        #expect(facingBet.allows(.call))
        #expect(!facingBet.allows(.check))
        #expect(!facingBet.allows(.raise(to: 39)))
        #expect(facingBet.allows(.raise(to: 40)))
        #expect(facingBet.allows(.raise(to: 100)))
        #expect(!facingBet.allows(.raise(to: 101)))

        #expect(state.legalActions(for: 1) == .empty)
        for illegalAction in [
            PlayerAction.check,
            .raise(to: -1),
            .raise(to: 39),
            .raise(to: 101),
        ] {
            let before = state
            expectApplication(illegalAction, by: 0, to: &state, expected: false)
            #expect(state == before)
        }

        expectApplication(.call, by: 1, to: &state, expected: false)
        expectApplication(.call, by: 0, to: &state)
        #expect(state.currentToAct == 1)

        let matchedBet = state.legalActions(for: 1)
        #expect(matchedBet.canFold)
        #expect(matchedBet.canCheck)
        #expect(!matchedBet.canCall)
        #expect(matchedBet.callAmount == 0)
        #expect(matchedBet.raiseBounds == 40...100)
        let beforeIllegalCall = state
        expectApplication(.call, by: 1, to: &state, expected: false)
        #expect(state == beforeIllegalCall)
    }

    @Test("successive full raises preserve or increase the minimum increment")
    func successiveFullRaises() {
        var state = makeBettingState([1_000, 1_000, 1_000], seed: 21)

        #expect(state.currentToAct == 0)
        expectApplication(.raise(to: 60), by: 0, to: &state)
        #expect(state.minRaise == 40)
        #expect(state.players[1].lastActionBet == nil)
        #expect(state.legalActions(for: 1).callAmount == 50)
        #expect(state.legalActions(for: 1).raiseBounds == 100...1_000)

        expectApplication(.raise(to: 140), by: 1, to: &state)
        #expect(state.minRaise == 80)
        #expect(state.legalActions(for: 2).callAmount == 120)
        #expect(state.legalActions(for: 2).raiseBounds == 220...1_000)

        expectApplication(.raise(to: 220), by: 2, to: &state)
        #expect(state.minRaise == 80)
        #expect(state.currentToAct == 0)
        #expect(state.legalActions(for: 0).callAmount == 160)
        #expect(state.legalActions(for: 0).raiseBounds == 300...1_000)

        expectApplication(.call, by: 0, to: &state)
        #expect(state.currentToAct == 1)
        #expect(state.legalActions(for: 1).callAmount == 80)
        #expect(state.legalActions(for: 1).raiseBounds == 300...1_000)
    }

    @Test("an isolated short all-in is a raise only for players who have not acted")
    func isolatedShortAllInDoesNotReopenPriorActors() {
        var state = makeBettingState([1_000, 100, 1_000, 1_000], seed: 22)

        #expect(state.currentToAct == 3)
        expectApplication(.raise(to: 80), by: 3, to: &state)
        expectApplication(.call, by: 0, to: &state)
        #expect(state.legalActions(for: 1).raiseBounds == 100...100)
        expectApplication(.raise(to: 100), by: 1, to: &state)
        #expect(state.minRaise == 60)

        let unactedBigBlind = state.legalActions(for: 2)
        #expect(unactedBigBlind.callAmount == 80)
        #expect(unactedBigBlind.raiseBounds == 160...1_000)
        expectApplication(.call, by: 2, to: &state)

        let priorRaiser = state.legalActions(for: 3)
        #expect(priorRaiser.callAmount == 20)
        #expect(priorRaiser.raiseBounds == nil)
        let beforeRejectedRaise = state
        expectApplication(.raise(to: 1_000), by: 3, to: &state, expected: false)
        #expect(state == beforeRejectedRaise)
        expectApplication(.call, by: 3, to: &state)

        let priorCaller = state.legalActions(for: 0)
        #expect(priorCaller.callAmount == 20)
        #expect(priorCaller.raiseBounds == nil)
    }

    @Test("cumulative short all-ins reopen at exactly one full increment")
    func cumulativeShortAllInThreshold() {
        for finalAllIn in [138, 139, 140, 141] {
            var state = makeBettingState(
                [90, finalAllIn, 1_000, 1_000, 1_000],
                seed: UInt64(finalAllIn))

            expectApplication(.raise(to: 80), by: 3, to: &state)
            expectApplication(.call, by: 4, to: &state)
            expectApplication(.raise(to: 90), by: 0, to: &state)
            expectApplication(.raise(to: finalAllIn), by: 1, to: &state)
            #expect(state.minRaise == 60)

            let unactedBigBlind = state.legalActions(for: 2)
            #expect(unactedBigBlind.raiseBounds == (finalAllIn + 60)...1_000)
            expectApplication(.call, by: 2, to: &state)
            #expect(state.currentToAct == 3)

            let actual = state.legalActions(for: 3)
            #expect(actual.callAmount == finalAllIn - 80)
            #expect(actual.raiseBounds == (finalAllIn >= 140 ? (finalAllIn + 60)...1_000 : nil))
        }
    }

    @Test("a short opening all-in does not reopen a prior checker")
    func shortOpeningAllInAfterCheck() {
        var state = makeBettingState([1_000, 1_000, 30], seed: 23)

        expectApplication(.call, by: 0, to: &state)
        expectApplication(.call, by: 1, to: &state)
        expectApplication(.check, by: 2, to: &state)
        #expect(state.street == .flop)
        #expect(state.currentToAct == 1)

        expectApplication(.check, by: 1, to: &state)
        #expect(state.currentToAct == 2)
        #expect(state.legalActions(for: 2).raiseBounds == 10...10)
        expectApplication(.raise(to: 10), by: 2, to: &state)

        let unactedPlayer = state.legalActions(for: 0)
        #expect(unactedPlayer.callAmount == 10)
        #expect(unactedPlayer.raiseBounds == 30...980)
        expectApplication(.call, by: 0, to: &state)

        let priorChecker = state.legalActions(for: 1)
        #expect(priorChecker.callAmount == 10)
        #expect(priorChecker.raiseBounds == nil)
        expectApplication(.call, by: 1, to: &state)
        #expect(state.street == .turn)
        #expect(state.currentToAct == 1)
    }

    @Test("heads-up and multiway action order survives raises and folds")
    func actorOrderAcrossTableShapes() {
        var headsUp = makeBettingState([1_000, 1_000], seed: 24)
        #expect(headsUp.currentToAct == 0)
        expectApplication(.call, by: 0, to: &headsUp)
        #expect(headsUp.currentToAct == 1)
        expectApplication(.raise(to: 60), by: 1, to: &headsUp)
        #expect(headsUp.currentToAct == 0)
        expectApplication(.call, by: 0, to: &headsUp)
        #expect(headsUp.street == .flop)
        #expect(headsUp.currentToAct == 1)
        expectApplication(.check, by: 1, to: &headsUp)
        #expect(headsUp.currentToAct == 0)
        expectApplication(.check, by: 0, to: &headsUp)
        #expect(headsUp.street == .turn)
        #expect(headsUp.currentToAct == 1)

        var multiway = makeBettingState(
            [1_000, 1_000, 1_000, 1_000, 1_000],
            dealerIndex: 1,
            seed: 25)
        #expect(multiway.currentToAct == 4)
        expectApplication(.fold, by: 4, to: &multiway)
        #expect(multiway.currentToAct == 0)
        expectApplication(.call, by: 0, to: &multiway)
        #expect(multiway.currentToAct == 1)
        expectApplication(.raise(to: 60), by: 1, to: &multiway)
        #expect(multiway.currentToAct == 2)
        expectApplication(.fold, by: 2, to: &multiway)
        #expect(multiway.currentToAct == 3)
        expectApplication(.call, by: 3, to: &multiway)
        #expect(multiway.currentToAct == 0)
        expectApplication(.call, by: 0, to: &multiway)
        #expect(multiway.street == .flop)
        #expect(multiway.currentToAct == 3)
        expectApplication(.check, by: 3, to: &multiway)
        #expect(multiway.currentToAct == 0)
        expectApplication(.check, by: 0, to: &multiway)
        #expect(multiway.currentToAct == 1)
        expectApplication(.check, by: 1, to: &multiway)
        #expect(multiway.street == .turn)
        #expect(multiway.currentToAct == 3)
    }
}
