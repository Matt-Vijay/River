import Testing
@testable import GameCore

@Suite("Next hand dealer")
struct NextHandDealerTests {
    @Test("next hand dealer advances in original seat order after a player leaves")
    func nextHandDealerSkipsLeftSeatsInOriginalOrder() throws {
        var s = GameState.startHand(players: makePlayers([1000, 1000, 1000]),
                                    dealerIndex: 2, smallBlind: 10, bigBlind: 20,
                                    seed: 1, handNumber: 1)
        s.playerLeaves(id: "p0")
        s.apply(.fold, by: 2)

        let next = try #require(s.startNextHand(seed: 2))

        #expect(next.players.map(\.id) == ["p1", "p2"])
        #expect(next.dealerIndex == 0)
        #expect(next.players[next.dealerIndex].id == "p1")
        #expect(totalChips(next) == 2010)
    }
}
