import Testing
@testable import GameCore

@Suite("Next hand eligibility")
struct NextHandEligibilityTests {
    @Test("exhausted counters cannot start the next hand")
    func exhaustedCountersCannotStartNextHand() {
        var s = GameState.startHand(players: makePlayers([1000, 1000]),
                                    dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                    seed: 1, handNumber: 1)
        s.results = []
        var exhausted = s
        exhausted.handNumber = Int.max
        #expect(exhausted.startNextHand(seed: 2) == nil)
        exhausted.handNumber = 1
        exhausted.version = Int.max
        #expect(exhausted.startNextHand(seed: 2) == nil)
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
        #expect(next.playersEligibleForNextHand.count == 3)
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

    @Test("dealer advances in original seat order after a player leaves")
    func dealerSkipsLeftSeatsInOriginalOrder() throws {
        var state = GameState.startHand(players: makePlayers([1000, 1000, 1000]),
                                        dealerIndex: 2, smallBlind: 10, bigBlind: 20,
                                        seed: 1, handNumber: 1)
        state.playerLeaves(id: "p0")
        state.apply(.fold, by: 2)

        let next = try #require(state.startNextHand(seed: 2))

        #expect(next.players.map(\.id) == ["p1", "p2"])
        #expect(next.dealerIndex == 0)
        #expect(next.players[next.dealerIndex].id == "p1")
        #expect(totalChips(next) == 2010)
    }

    @Test("stacks carry forward and chips remain conserved")
    func stacksCarryForward() throws {
        var state = GameState.startHand(players: makePlayers([1000, 1000]),
                                        dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                        seed: 1, handNumber: 1)
        state.apply(.fold, by: 0)
        #expect(state.players[1].stack == 1010)
        #expect(state.players[0].stack == 990)

        let next = try #require(state.startNextHand(seed: 2))

        #expect(next.handNumber == 2)
        #expect(totalChips(next) == 2000)
        #expect(next.players[1].stack + next.players[1].bet == 1010)
        #expect(next.players[0].stack + next.players[0].bet == 990)
    }
}
