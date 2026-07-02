import Testing
@testable import GameCore

@Suite("Betting resolution")
struct BettingResolutionTests {
    @Test("folding hands the pot to the last player")
    func foldWins() {
        var s = GameState.startHand(players: makePlayers([1000, 1000]),
                                    dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                    seed: 1, handNumber: 1)
        s.apply(.fold, by: 0)
        #expect(s.contenders.count == 1)
        #expect(s.players[1].stack == 1010)  // 980 left + 30 pot
        #expect(s.players[0].stack == 990)
        #expect(s.results?.count == 1)
        #expect(s.results?.first?.playerID == "p1")
        #expect(totalChips(s) == 2000)
    }

    @Test("checking down reaches showdown and conserves chips")
    func checkDownToShowdown() throws {
        var s = GameState.startHand(players: makePlayers([1000, 1000]),
                                    dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                    seed: 42, handNumber: 1)
        checkOrCallToShowdown(&s)
        #expect(s.street == .showdown)
        #expect(s.currentToAct == nil)
        #expect(s.board.count == 5)
        let results = try #require(s.results)
        let totalWon = results.reduce(0) { $0 + $1.amountWon }
        #expect(totalWon == 40)               // both put in 20
        #expect(totalChips(s) == 2000)
        #expect(results.allSatisfy { $0.handName != nil })  // showdown reveals hands
    }

    @Test("showdown runout tolerates malformed short decks")
    func showdownRunoutToleratesMalformedShortDecks() {
        var s = GameState.startHand(players: makePlayers([1000, 1000]),
                                    dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                    seed: 42, handNumber: 1)
        s.board = []
        s.deck = cards("Ah Kh")

        s.runOutAndShowdown()

        #expect(s.street == .showdown)
        #expect(s.board == cards("Ah Kh"))
        #expect(s.deck.isEmpty)
    }
}
