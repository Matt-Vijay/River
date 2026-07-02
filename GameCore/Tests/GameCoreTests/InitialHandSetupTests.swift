import Testing
@testable import GameCore

@Suite("Initial hand setup")
struct InitialHandSetupTests {
    @Test("heads-up: dealer is small blind and acts first preflop")
    func headsUpBlinds() {
        let s = GameState.startHand(players: makePlayers([1000, 1000]),
                                    dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                    seed: 1, handNumber: 1)
        #expect(s.players[0].bet == 10)   // dealer posts SB
        #expect(s.players[1].bet == 20)   // other posts BB
        #expect(s.currentBet == 20)
        #expect(s.currentToAct == 0)      // dealer acts first heads-up
        #expect(s.players.allSatisfy { $0.holeCards.count == 2 })
        #expect(s.deck.count == 48)
        #expect(s.displayPot == 30)
    }

    @Test("three-handed: blinds left of dealer, UTG acts first")
    func threeHandedBlinds() {
        let s = GameState.startHand(players: makePlayers([1000, 1000, 1000]),
                                    dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                    seed: 2, handNumber: 1)
        #expect(s.players[1].bet == 10)   // SB
        #expect(s.players[2].bet == 20)   // BB
        #expect(s.currentToAct == 0)      // dealer is UTG three-handed
        #expect(s.deck.count == 46)
    }

    @Test("dealer index is normalized before dealing")
    func dealerIndexIsNormalized() {
        let positive = GameState.startHand(players: makePlayers([1000, 1000, 1000]),
                                           dealerIndex: 5, smallBlind: 10, bigBlind: 20,
                                           seed: 2, handNumber: 1)
        #expect(positive.dealerIndex == 2)
        #expect(positive.players[0].bet == 10)
        #expect(positive.players[1].bet == 20)
        #expect(positive.currentToAct == 2)

        let negative = GameState.startHand(players: makePlayers([1000, 1000, 1000]),
                                           dealerIndex: -1, smallBlind: 10, bigBlind: 20,
                                           seed: 2, handNumber: 1)
        #expect(negative.dealerIndex == 2)
        #expect(negative.players[0].bet == 10)
        #expect(negative.players[1].bet == 20)
        #expect(negative.currentToAct == 2)
    }

    @Test("invalid blinds are normalized before betting state is created")
    func invalidBlindsAreNormalized() {
        let s = GameState.startHand(players: makePlayers([1000, 1000]),
                                    dealerIndex: 0, smallBlind: -10, bigBlind: -20,
                                    seed: 1, handNumber: 1)

        #expect(s.smallBlind == 1)
        #expect(s.bigBlind == 2)
        #expect(s.currentBet == 2)
        #expect(s.minRaise == 2)
        #expect(s.players[0].bet == 1)
        #expect(s.players[1].bet == 2)
    }

    @Test("big blind is repaired when smaller than the small blind")
    func shortBigBlindIsRepaired() {
        let s = GameState.startHand(players: makePlayers([1000, 1000]),
                                    dealerIndex: 0, smallBlind: 10, bigBlind: 5,
                                    seed: 1, handNumber: 1)

        #expect(s.smallBlind == 10)
        #expect(s.bigBlind == 20)
        #expect(s.currentBet == 20)
        #expect(s.minRaise == 20)
        #expect(s.players[0].bet == 10)
        #expect(s.players[1].bet == 20)
    }

    @Test("invalid hand counters are normalized before betting state is created")
    func invalidHandCountersAreNormalized() {
        let s = GameState.startHand(players: makePlayers([1000, 1000]),
                                    dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                    seed: 1, handNumber: -4, turnDuration: -30)

        #expect(s.handNumber == 1)
        #expect(s.turnDuration == TurnClock.defaultDuration)
    }

    @Test("departed players are not dealt into a fresh hand")
    func departedPlayersAreNotDealtIn() {
        var players = makePlayers([1000, 1000, 1000])
        players[1].hasLeft = true

        let s = GameState.startHand(players: players,
                                    dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                    seed: 3, handNumber: 1)

        #expect(s.players[1].status == .sittingOut)
        #expect(s.players[1].holeCards.isEmpty)
        #expect(s.players[1].bet == 0)
        #expect(s.players[0].holeCards.count == 2)
        #expect(s.players[2].holeCards.count == 2)
        #expect(s.deck.count == 48)
    }

    @Test("hole-card dealing tolerates malformed short decks")
    func holeCardDealingToleratesMalformedShortDecks() {
        var players = makePlayers([1000, 1000])
        var deck = cards("Ah")

        GameState.dealHoleCards(to: &players, deck: &deck, dealOrder: [0, 1])

        #expect(players[0].holeCards == cards("Ah"))
        #expect(players[1].holeCards.isEmpty)
        #expect(deck.isEmpty)
    }
}
