import Testing

@testable import GameCore

@Suite("Side-pot settlement")
struct SidePotTests {
    @Test("main and side pots pay their respective winners")
    func mainAndSidePotWinners() {
        let state = settledState(
            committed: [100, 50, 100],
            statuses: [.allIn, .allIn, .allIn],
            hands: ["Qc Qd", "Ah 5h", "Jc Jh"]
        )

        #expect(state.players.map(\.stack) == [100, 150, 0])
        #expect(winnings(in: state) == ["p0": 100, "p1": 150])
    }

    @Test("an unmatched all-in layer returns to its only eligible player")
    func unmatchedLayer() {
        let state = settledState(
            committed: [300, 400],
            statuses: [.allIn, .allIn],
            hands: ["Ah 5h", "Qc Qd"]
        )

        #expect(state.players.map(\.stack) == [600, 100])
        #expect(winnings(in: state) == ["p0": 600, "p1": 100])
    }

    @Test("a folded player's unmatched layer is refunded")
    func foldedOnlyLayer() {
        let state = settledState(
            committed: [50, 0, 100],
            statuses: [.allIn, .folded, .folded],
            hands: ["", "", ""]
        )

        #expect(state.players.map(\.stack) == [100, 0, 50])
        #expect(winnings(in: state) == ["p0": 100])
    }

    @Test("folded chips stay in the pot and odd chips start left of the dealer")
    func foldedContributorAndOddChipOrder() {
        let state = settledState(
            committed: [1, 1, 1],
            statuses: [.allIn, .folded, .allIn],
            hands: ["2d 3s", "4d 5s", "6d 7s"],
            board: "Ah Kh Qh Jh Th",
            dealerIndex: -5
        )

        #expect(state.players.map(\.stack) == [1, 0, 2])
        #expect(winnings(in: state) == ["p0": 1, "p2": 2])
    }

    private func settledState(
        committed: [Int],
        statuses: [PlayerStatus],
        hands: [String],
        board: String = "2c 3d 4s 9c Kd",
        dealerIndex: Int = 0
    ) -> GameState {
        var players = makePlayers(committed.map { _ in 0 })
        for index in players.indices {
            players[index].committed = committed[index]
            players[index].status = statuses[index]
            players[index].holeCards = cards(hands[index])
        }
        var state = GameState(
            tableID: "side-pot-test", handNumber: 1,
            players: players, dealerIndex: dealerIndex, smallBlind: 10, bigBlind: 20,
            board: cards(board), deck: [], street: .river, currentToAct: nil,
            minRaise: 20, turnStartedAt: nil, turnDuration: 30,
            results: nil, version: 0
        )
        state.advance(now: .distantPast)
        return state
    }

    private func winnings(in state: GameState) -> [String: Int] {
        Dictionary(uniqueKeysWithValues: (state.results ?? []).map {
            ($0.playerID, $0.amountWon)
        })
    }
}
