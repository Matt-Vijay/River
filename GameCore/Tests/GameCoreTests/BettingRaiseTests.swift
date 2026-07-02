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
        #expect(s.players[1].hasActed == false)
        let legal = s.legalActions(for: 1)
        #expect(legal.callAmount == 40)       // BB already has 20 in
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

    @Test("a raise above all-in is rejected")
    func raiseAboveAllInIsRejected() {
        var s = GameState.startHand(players: makePlayers([1000, 1000]),
                                    dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                    seed: 7, handNumber: 1)

        let before = s

        #expect(s.apply(.raise(to: 1_001), by: 0) == false)
        #expect(s == before)
    }

    @Test("legal actions validate the requested raise total")
    func legalActionsValidateRequestedRaiseTotal() {
        let s = GameState.startHand(players: makePlayers([1000, 1000]),
                                    dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                    seed: 7, handNumber: 1)
        let legal = s.legalActions(for: 0)

        #expect(legal.allows(.raise(to: legal.minRaiseTo)))
        #expect(legal.allows(.raise(to: legal.maxRaiseTo)))
        #expect(!legal.allows(.raise(to: legal.minRaiseTo - 1)))
        #expect(!legal.allows(.raise(to: legal.maxRaiseTo + 1)))
    }

    @Test("pot-sized raise preset includes the call before sizing the raise")
    func potSizedRaisePresetIncludesCall() {
        let s = GameState.startHand(players: makePlayers([1000, 1000]),
                                    dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                    seed: 1, handNumber: 1)
        let legal = s.legalActions(for: 0)

        #expect(legal.recommendedRaiseTo(.halfPot, pot: s.displayPot) == 40)
        #expect(legal.recommendedRaiseTo(.pot, pot: s.displayPot) == 60)
    }
}
