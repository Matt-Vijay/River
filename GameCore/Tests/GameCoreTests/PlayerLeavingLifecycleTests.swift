import Testing
@testable import GameCore

@Suite("Player leaving lifecycle")
struct PlayerLeavingLifecycleTests {
    @Test("when a player leaves heads-up, the other wins and the game is over")
    func leaveEndsHeadsUp() {
        var s = GameState.startHand(players: makePlayers([1000, 1000]),
                                    dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                    seed: 1, handNumber: 1)
        s.playerLeaves(id: "p0")                 // dealer leaves
        #expect(s.players[0].hasLeft)
        #expect(s.results != nil)                // hand awarded to the other
        #expect(s.overallWinner?.id == "p1")     // one player left -> game over
        #expect(s.fundedPlayerCount == 1)
    }

    @Test("leaving 3-handed continues the hand among the rest")
    func leaveThreeHanded() throws {
        var s = GameState.startHand(players: makePlayers([1000, 1000, 1000]),
                                    dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                    seed: 2, handNumber: 1)
        let utg = try #require(s.currentToAct)
        s.playerLeaves(id: s.players[utg].id)    // a non-blind leaves
        #expect(s.players.first { $0.id == s.players[utg].id }?.hasLeft == true)
        #expect(s.results == nil)                // two players still contest
        #expect(s.overallWinner == nil)
        #expect(s.fundedPlayerCount == 2)
    }

    @Test("leaving after hand completion does not fold the completed hand")
    func leaveAfterHandCompletionOnlyMarksPlayerLeft() throws {
        var s = GameState.startHand(players: makePlayers([1000, 1000]),
                                    dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                    seed: 1, handNumber: 1)
        s.apply(.fold, by: 0)
        let winnerIndex = try #require(s.playerIndex(id: "p1"))
        let results = s.results
        let status = s.players[winnerIndex].status
        let lastAction = s.players[winnerIndex].lastAction

        #expect(s.playerLeaves(id: "p1") == true)

        #expect(s.players[winnerIndex].hasLeft)
        #expect(s.players[winnerIndex].status == status)
        #expect(s.players[winnerIndex].lastAction == lastAction)
        #expect(s.results == results)
    }

    @Test("leaving cannot mutate a game over table")
    func leaveCannotMutateGameOverTable() throws {
        var s = GameState.startHand(players: makePlayers([1000, 1000]),
                                    dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                    seed: 1, handNumber: 1)
        s.playerLeaves(id: "p0")
        let winner = try #require(s.overallWinner?.id)
        let before = s

        #expect(s.playerLeaves(id: winner) == false)
        #expect(s == before)
    }
}
