import Testing
@testable import GameCore

@Suite("Table summaries")
struct TableSummaryTests {
    @Test("message summary describes lobby readiness")
    func lobbyMessageSummary() {
        let lobby = Lobby(maxPlayers: 6, seats: [
            LobbySeat(id: "host", name: "Alice", avatar: "A", isReady: true),
            LobbySeat(id: "guest", name: "Bob", avatar: "B", isReady: false),
        ])

        let summary = GamePayload.summary(for: .lobby(lobby))

        #expect(summary == "Lobby · 2/6 joined · 1 ready")
    }

    @Test("summary describes the live hand")
    func liveSummary() {
        let state = sixPlayerState()
        let summary = GamePayload.summary(for: state)
        #expect(summary.contains("Pre-flop"))
        #expect(summary.contains("to act"))
    }

    @Test("summary formats large live pots")
    func liveSummaryFormatsLargePots() {
        var state = sixPlayerState()
        state.pot = 1_200

        let summary = GamePayload.summary(for: state)

        #expect(summary.contains("Pot 1,230"))
    }

    @Test("summary tolerates an invalid current actor index")
    func summaryToleratesInvalidCurrentActor() {
        var state = sixPlayerState()
        state.currentToAct = 99

        let summary = GamePayload.summary(for: state)

        #expect(state.currentPlayer == nil)
        #expect(summary == "Pre-flop · Pot \(state.displayPot)")
    }

    @Test("live summaries shorten long actor names")
    func liveSummariesShortenLongActorNames() {
        var state = GameState.startHand(players: [
            Player(id: "a", name: "Alexandria The Great", avatar: "A", stack: 1000),
            Player(id: "b", name: "Bob", avatar: "B", stack: 1000),
        ], dealerIndex: 0, smallBlind: 10, bigBlind: 20, seed: 1, handNumber: 1)
        state.currentToAct = 0

        let summary = GamePayload.summary(for: state)

        #expect(summary.contains("Alexandria The Gr… to act"))
        #expect(!summary.contains("Alexandria The Great to act"))
    }

    @Test("summary describes the result at showdown")
    func resultSummary() {
        var state = GameState.startHand(players: [
            Player(id: "a", name: "Alice", avatar: "🙂", stack: 1000),
            Player(id: "b", name: "Bob", avatar: "🙂", stack: 1000),
        ], dealerIndex: 0, smallBlind: 10, bigBlind: 20, seed: 1, handNumber: 1)
        state.apply(.fold, by: 0)
        let summary = GamePayload.summary(for: state)
        #expect(summary.contains("Bob won"))
    }

    @Test("summary formats large hand results")
    func resultSummaryFormatsLargeAmounts() {
        var state = GameState.startHand(players: [
            Player(id: "a", name: "Alice", avatar: "🙂", stack: 2_000),
            Player(id: "b", name: "Bob", avatar: "🙂", stack: 2_000),
        ], dealerIndex: 0, smallBlind: 500, bigBlind: 1_000, seed: 1, handNumber: 1)
        state.apply(.fold, by: 0)

        let summary = GamePayload.summary(for: state)

        #expect(summary == "Bob won 1,500")
    }

    @Test("summary describes split pots")
    func resultSummaryDescribesSplitPots() {
        var state = GameState.startHand(players: [
            Player(id: "a", name: "Alice", avatar: "🙂", stack: 1000),
            Player(id: "b", name: "Bob", avatar: "🙂", stack: 1000),
            Player(id: "c", name: "Cara", avatar: "🙂", stack: 1000),
        ], dealerIndex: 0, smallBlind: 10, bigBlind: 20, seed: 1, handNumber: 1)
        state.results = [
            HandResult(playerID: "a", amountWon: 100, handName: "Pair", bestFive: nil),
            HandResult(playerID: "b", amountWon: 100, handName: "Pair", bestFive: nil),
            HandResult(playerID: "c", amountWon: 0, handName: nil, bestFive: nil),
        ]

        let summary = GamePayload.summary(for: state)

        #expect(summary == "Alice and Bob split 100")
    }

    @Test("result summaries shorten long winner names")
    func resultSummariesShortenLongWinnerNames() {
        var state = GameState.startHand(players: [
            Player(id: "a", name: "Alexandria The Great", avatar: "A", stack: 1000),
            Player(id: "b", name: "Bartholomew The Bold", avatar: "B", stack: 1000),
        ], dealerIndex: 0, smallBlind: 10, bigBlind: 20, seed: 1, handNumber: 1)
        state.results = [
            HandResult(playerID: "a", amountWon: 100, handName: "Pair", bestFive: nil),
            HandResult(playerID: "b", amountWon: 100, handName: "Pair", bestFive: nil),
        ]

        let summary = GamePayload.summary(for: state)

        #expect(summary == "Alexandria The Gr… and Bartholomew The B… split 100")
    }

    @Test("summary describes the overall game winner")
    func gameOverSummary() {
        var state = GameState.startHand(players: [
            Player(id: "a", name: "Alice", avatar: "A", stack: 1000),
            Player(id: "b", name: "Bob", avatar: "B", stack: 1000),
        ], dealerIndex: 0, smallBlind: 10, bigBlind: 20, seed: 1, handNumber: 1)
        let didLeave = state.playerLeaves(id: "b")

        let summary = GamePayload.summary(for: state)

        #expect(didLeave)
        #expect(state.overallWinner?.name == "Alice")
        #expect(summary == "Alice wins the game")
    }

    @Test("summary does not call a live all-in hand game over")
    func liveAllInSummaryIsNotGameOver() {
        var state = GameState.startHand(players: makePlayers([40, 1000]),
                                        dealerIndex: 0,
                                        smallBlind: 10,
                                        bigBlind: 20,
                                        seed: 11,
                                        handNumber: 1)
        state.apply(.raise(to: 40), by: 0)

        let summary = GamePayload.summary(for: state)

        #expect(state.isHandComplete == false)
        #expect(summary != "P1 wins the game")
        #expect(summary.contains("Pre-flop"))
    }
}
