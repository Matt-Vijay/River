import Testing
@testable import GameCore

@Suite("GameState lookup")
struct GameStateLookupTests {
    @Test("player lookup hides player-array details")
    func playerLookup() {
        let s = GameState.startHand(players: makePlayers([1000, 1000, 1000]),
                                    dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                    seed: 2, handNumber: 1)

        #expect(s.playerIndex(id: "p1") == 1)
        #expect(s.player(id: "p1")?.id == "p1")
        #expect(s.containsPlayer(id: "p1"))
        #expect(s.player(at: 1)?.id == "p1")
        #expect(s.player(at: -1) == nil)
        #expect(s.player(at: 99) == nil)
        #expect(s.playerIndex(id: "missing") == nil)
        #expect(s.player(id: "missing") == nil)
        #expect(!s.containsPlayer(id: "missing"))
    }

    @Test("current-player checks hide optional index details")
    func currentPlayerChecks() {
        var s = GameState.startHand(players: makePlayers([1000, 1000, 1000]),
                                    dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                    seed: 2, handNumber: 1)

        #expect(s.isCurrentPlayer(at: 0))
        #expect(!s.isCurrentPlayer(at: 1))
        #expect(!s.isCurrentPlayer(at: -1))

        s.currentToAct = nil
        #expect(!s.isCurrentPlayer(at: 0))
    }

    @Test("current hand rank ignores invalid player indexes")
    func currentHandRankIgnoresInvalidIndex() {
        let s = GameState.startHand(players: makePlayers([1000, 1000]),
                                    dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                    seed: 1, handNumber: 1)

        #expect(s.currentHandRank(for: -1) == nil)
        #expect(s.currentHandRank(for: 99) == nil)
    }
}
