import Testing
@testable import GameCore

@Suite("Game over lifecycle")
struct GameOverLifecycleTests {
    @Test("game over is detected when only one player has chips")
    func gameOverDetection() {
        // Heads-up, one player all-in and loses everything.
        var s = GameState.startHand(players: makePlayers([40, 1000]),
                                    dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                    seed: 11, handNumber: 1)
        s.apply(.raise(to: 40), by: 0)   // short stack shoves
        s.apply(.call, by: 1)
        #expect(s.street == .showdown)
        // Exactly one of them may now be busted; game-over iff one has all chips.
        let funded = s.players.filter { $0.stack > 0 }.count
        #expect(s.fundedPlayerCount == funded)
        if funded == 1 {
            #expect(s.overallWinner != nil)
            #expect(s.isGameOver)
            #expect(s.overallWinner?.stack == 1040)
        } else {
            #expect(s.overallWinner == nil)   // split / chop, still 2 funded
            #expect(!s.isGameOver)
        }
        // A fresh full table is never game-over.
        let fresh = GameState.startHand(players: makePlayers([1000, 1000, 1000]),
                                        dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                        seed: 1, handNumber: 1)
        #expect(fresh.overallWinner == nil)
        #expect(!fresh.isGameOver)
        #expect(fresh.fundedPlayerCount == 3)
    }

    @Test("all-in player with no stack is not game over until the hand is complete")
    func allInPlayerWithNoStackIsNotGameOverUntilHandComplete() {
        var s = GameState.startHand(players: makePlayers([40, 1000]),
                                    dealerIndex: 0,
                                    smallBlind: 10,
                                    bigBlind: 20,
                                    seed: 11,
                                    handNumber: 1)

        s.apply(.raise(to: 40), by: 0)

        #expect(s.players[0].status == .allIn)
        #expect(s.players[0].stack == 0)
        #expect(s.isHandComplete == false)
        #expect(s.contenders.count == 2)
        #expect(s.overallWinner == nil)
        #expect(!s.isGameOver)
    }
}
