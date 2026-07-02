import Testing
@testable import GameCore

@Suite("Next hand eligibility")
struct NextHandEligibilityTests {
    @Test("a live hand cannot be replaced by the next hand")
    func liveHandCannotStartNextHand() {
        let s = GameState.startHand(players: makePlayers([1000, 1000]),
                                    dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                    seed: 1, handNumber: 1)

        #expect(s.startNextHand(seed: 2) == nil)
    }

    @Test("a left player is excluded from the next deal, others carry on")
    func leftPlayerExcludedNextDeal() throws {
        var s = GameState.startHand(players: makePlayers([1000, 1000, 1000]),
                                    dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                    seed: 2, handNumber: 1)
        s.players[2].hasLeft = true
        s.results = [HandResult(playerID: "p0", amountWon: 0, handName: nil, bestFive: nil)]

        let next = try #require(s.startNextHand(seed: 3))

        #expect(next.players.count == 2)
        #expect(!next.players.contains { $0.id == "p2" })
    }

    @Test("a player who joins mid-game is dealt in on the next hand")
    func joinerSeatedNextHand() throws {
        var s = GameState.startHand(players: makePlayers([1000, 1000]),
                                    dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                    seed: 1, handNumber: 1)
        // A new participant appends themselves (sitting out the current hand).
        var joiner = Player(id: "p2", name: "newcomer", avatar: "fox", stack: 1000)
        joiner.status = .sittingOut
        s.players.append(joiner)
        #expect(s.contenders.count == 2)            // joiner not in the live hand
        s.results = [HandResult(playerID: "p0", amountWon: 0, handName: nil, bestFive: nil)]

        let next = try #require(s.startNextHand(seed: 2))

        #expect(next.players.count == 3)
        #expect(next.players[2].holeCards.count == 2)  // dealt in now
        #expect(next.players[2].status == .active)
        #expect(next.fundedPlayerCount == 3)
    }

    @Test("next hand excludes busted and left players")
    func nextHandExcludesUnavailablePlayers() throws {
        var s = GameState.startHand(players: makePlayers([1000, 1000, 1000, 1000]),
                                    dealerIndex: 1, smallBlind: 10, bigBlind: 20,
                                    seed: 1, handNumber: 1)
        s.players[0].hasLeft = true
        s.players[2].stack = 0
        s.results = [HandResult(playerID: "p1", amountWon: 0,
                                handName: nil, bestFive: nil)]

        let next = try #require(s.startNextHand(seed: 2))

        #expect(next.players.map(\.id) == ["p1", "p3"])
        #expect(next.dealerIndex == 1)
        #expect(next.players[next.dealerIndex].id == "p3")
    }
}
