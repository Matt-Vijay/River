import Testing
@testable import GameCore

@Suite("Next hand stacks")
struct NextHandStackTests {
    @Test("next hand carries stacks forward and conserves chips")
    func nextHandCarriesStacks() throws {
        var s = GameState.startHand(players: makePlayers([1000, 1000]),
                                    dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                    seed: 1, handNumber: 1)
        s.apply(.fold, by: 0)                       // p1 wins the blinds
        #expect(s.players[1].stack == 1010)
        #expect(s.players[0].stack == 990)

        let next = try #require(s.startNextHand(seed: 2))

        #expect(next.handNumber == 2)
        #expect(totalChips(next) == 2000)           // chips persist across hands
        // The chip leader from last hand is still ahead going in (1010 vs 990).
        let p1Committed = next.players[1].stack + next.players[1].bet
        let p0Committed = next.players[0].stack + next.players[0].bet
        #expect(p1Committed == 1010)
        #expect(p0Committed == 990)
    }
}
