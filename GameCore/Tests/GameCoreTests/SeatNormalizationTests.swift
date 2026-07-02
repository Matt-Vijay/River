import Testing
@testable import GameCore

@Suite("Seat normalization")
struct SeatNormalizationTests {
    @Test("dealer checks normalize malformed stored indexes")
    func dealerChecksNormalizeMalformedIndexes() {
        var s = GameState.startHand(players: makePlayers([1000, 1000, 1000]),
                                    dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                    seed: 2, handNumber: 1)

        s.dealerIndex = -5

        #expect(s.dealerSeatIndex == 1)
        #expect(s.isDealer(at: 1))
        #expect(!s.isDealer(at: 0))
        #expect(!s.isDealer(at: -1))
    }

    @Test("first actor after dealer normalizes malformed stored indexes")
    func firstActorAfterDealerNormalizesMalformedIndexes() {
        var s = GameState.startHand(players: makePlayers([1000, 1000, 1000]),
                                    dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                    seed: 2, handNumber: 1)

        s.dealerIndex = -5

        #expect(s.firstActorAfterDealer == 2)
    }

    @Test("next seat normalizes malformed starting indexes")
    func nextSeatNormalizesMalformedStartingIndexes() {
        let s = GameState.startHand(players: makePlayers([1000, 1000, 1000]),
                                    dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                    seed: 2, handNumber: 1)

        #expect(s.nextSeat(after: -5) { $0.canAct } == 2)
        #expect(s.nextSeat(after: 5) { $0.canAct } == 0)
    }

    @Test("next hand normalizes malformed stored dealer index")
    func nextHandNormalizesMalformedDealerIndex() throws {
        var s = GameState.startHand(players: makePlayers([1000, 1000, 1000]),
                                    dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                    seed: 1, handNumber: 1)
        s.dealerIndex = -5
        s.results = [HandResult(playerID: "p0", amountWon: 0,
                                handName: nil, bestFive: nil)]

        let next = try #require(s.startNextHand(seed: 2))

        #expect(next.dealerIndex == 2)
        #expect(next.players[next.dealerIndex].id == "p2")
    }
}
