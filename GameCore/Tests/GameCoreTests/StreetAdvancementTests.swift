import Testing
@testable import GameCore

@Suite("Street advancement")
struct StreetAdvancementTests {
    @Test("street advancement deals flop turn and river card counts")
    func streetAdvancementDealsBoardCards() throws {
        var s = GameState.startHand(players: makePlayers([1000, 1000]),
                                    dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                    seed: 7, handNumber: 1)

        try completeCurrentBettingRound(&s)
        #expect(s.street == .flop)
        #expect(s.board.count == 3)

        try completeCurrentBettingRound(&s)
        #expect(s.street == .turn)
        #expect(s.board.count == 4)

        try completeCurrentBettingRound(&s)
        #expect(s.street == .river)
        #expect(s.board.count == 5)
    }

    @Test("street advancement normalizes malformed dealer index")
    func streetAdvancementNormalizesMalformedDealerIndex() {
        var s = GameState.startHand(players: makePlayers([1000, 1000, 1000]),
                                    dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                    seed: 2, handNumber: 1)
        s.dealerIndex = -5

        s.apply(.call, by: 0)
        s.apply(.call, by: 1)
        s.apply(.check, by: 2)

        #expect(s.street == .flop)
        #expect(s.currentToAct == 2)
    }

    @Test("street advancement tolerates malformed short decks")
    func streetAdvancementToleratesMalformedShortDecks() throws {
        var s = GameState.startHand(players: makePlayers([1000, 1000]),
                                    dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                    seed: 7, handNumber: 1)
        s.deck = cards("Ah")

        try completeCurrentBettingRound(&s)

        #expect(s.street == .flop)
        #expect(s.board == cards("Ah"))
        #expect(s.deck.isEmpty)
    }

    private func completeCurrentBettingRound(_ state: inout GameState) throws {
        let startingStreet = state.street
        var guardCount = 0
        while state.street == startingStreet, let index = state.currentToAct, guardCount < 20 {
            let legal = state.legalActions(for: index)
            state.apply(legal.canCheck ? .check : .call, by: index)
            guardCount += 1
        }
        #expect(state.street != startingStreet)
    }
}
