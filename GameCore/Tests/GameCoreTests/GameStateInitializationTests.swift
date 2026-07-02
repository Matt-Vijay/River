import Testing
import Foundation
@testable import GameCore

@Suite("Game state initialization")
struct GameStateInitializationTests {
    @Test("empty table identities are replaced")
    func emptyTableIdentitiesAreReplaced() {
        let state = GameState(
            tableID: "",
            handNumber: 1,
            players: makePlayers([100, 100]),
            dealerIndex: 0,
            smallBlind: 5,
            bigBlind: 10,
            board: [],
            deck: [],
            pot: 0,
            street: .preflop,
            currentToAct: nil,
            currentBet: 0,
            minRaise: 10,
            turnStartedAt: nil,
            turnDuration: 30,
            results: nil,
            version: 0
        )

        #expect(!state.tableID.isEmpty)
    }

    @Test("operation history is ordered and unique")
    func operationHistoryIsOrderedAndUnique() {
        let state = GameState(
            appliedOperationIDs: ["op-1", "", " op-2 ", "op-1", "op-3", "   ", "op-2"],
            handNumber: 1,
            players: makePlayers([100, 100]),
            dealerIndex: 0,
            smallBlind: 5,
            bigBlind: 10,
            board: [],
            deck: [],
            pot: 0,
            street: .preflop,
            currentToAct: nil,
            currentBet: 0,
            minRaise: 10,
            turnStartedAt: nil,
            turnDuration: 30,
            results: nil,
            version: 0
        )

        #expect(state.appliedOperationIDs == ["op-1", "op-2", "op-3"])
    }

    @Test("player identities are non-empty and unique")
    func playerIdentitiesAreNonEmptyAndUnique() {
        var players = makePlayers([100, 100, 100])
        players[0].id = ""
        players[2].id = players[1].id

        let state = GameState(
            handNumber: 1,
            players: players,
            dealerIndex: 0,
            smallBlind: 5,
            bigBlind: 10,
            board: [],
            deck: [],
            pot: 0,
            street: .preflop,
            currentToAct: nil,
            currentBet: 0,
            minRaise: 10,
            turnStartedAt: nil,
            turnDuration: 30,
            results: nil,
            version: 0
        )

        #expect(state.players.allSatisfy { !$0.id.isEmpty })
        #expect(Set(state.players.map(\.id)).count == state.players.count)
        #expect(state.players[1].id == "p1")
    }

    @Test("player hole cards are capped to holdem size")
    func playerHoleCardsAreCappedToHoldemSize() {
        var players = makePlayers([100, 100])
        players[0].holeCards = cards("Ah Kh Qh")

        let state = GameState(
            handNumber: 1,
            players: players,
            dealerIndex: 0,
            smallBlind: 5,
            bigBlind: 10,
            board: [],
            deck: [],
            pot: 0,
            street: .preflop,
            currentToAct: nil,
            currentBet: 0,
            minRaise: 10,
            turnStartedAt: nil,
            turnDuration: 30,
            results: nil,
            version: 0
        )

        #expect(state.players[0].holeCards == cards("Ah Kh"))
    }

    @Test("departed players cannot remain active in live hands")
    func departedPlayersCannotRemainActiveInLiveHands() {
        var players = makePlayers([100, 100])
        players[0].hasLeft = true
        players[0].status = .active

        let state = GameState(
            handNumber: 1,
            players: players,
            dealerIndex: 0,
            smallBlind: 5,
            bigBlind: 10,
            board: [],
            deck: [],
            pot: 0,
            street: .preflop,
            currentToAct: 0,
            currentBet: 0,
            minRaise: 10,
            turnStartedAt: nil,
            turnDuration: 30,
            results: nil,
            version: 0
        )

        #expect(state.players[0].status == .folded)
        #expect(!state.players[0].isContesting)
        #expect(state.currentToAct == nil)
    }

    @Test("completed hands do not keep an actor clock")
    func completedHandsDoNotKeepActorClock() {
        let startedAt = Date()
        let state = GameState(
            handNumber: 1,
            players: makePlayers([100, 100]),
            dealerIndex: 0,
            smallBlind: 5,
            bigBlind: 10,
            board: [],
            deck: [],
            pot: 0,
            street: .showdown,
            currentToAct: 0,
            currentBet: 0,
            minRaise: 10,
            turnStartedAt: startedAt,
            turnDuration: 30,
            results: [
                HandResult(playerID: "p0", amountWon: 20, handName: nil, bestFive: nil),
            ],
            version: 0
        )

        #expect(state.currentToAct == nil)
        #expect(state.turnStartedAt == nil)
    }

    @Test("completed hands normalize to showdown")
    func completedHandsNormalizeToShowdown() {
        let state = GameState(
            handNumber: 1,
            players: makePlayers([100, 100]),
            dealerIndex: 0,
            smallBlind: 5,
            bigBlind: 10,
            board: [],
            deck: [],
            pot: 0,
            street: .flop,
            currentToAct: nil,
            currentBet: 0,
            minRaise: 10,
            turnStartedAt: nil,
            turnDuration: 30,
            results: [
                HandResult(playerID: "p0", amountWon: 20, handName: "Pair", bestFive: nil),
            ],
            version: 0
        )

        #expect(state.street == .showdown)
    }

    @Test("completed hands clear live betting state")
    func completedHandsClearLiveBettingState() {
        var players = makePlayers([100, 100])
        players[0].bet = 10
        players[0].hasActed = true
        players[1].bet = 20
        players[1].hasActed = true

        let state = GameState(
            handNumber: 1,
            players: players,
            dealerIndex: 0,
            smallBlind: 5,
            bigBlind: 10,
            board: [],
            deck: [],
            pot: 50,
            street: .showdown,
            currentToAct: nil,
            currentBet: 20,
            minRaise: 10,
            turnStartedAt: nil,
            turnDuration: 30,
            results: [
                HandResult(playerID: "p0", amountWon: 80, handName: nil, bestFive: nil),
            ],
            version: 0
        )

        #expect(state.pot == 0)
        #expect(state.currentBet == 0)
        #expect(state.players.allSatisfy { $0.bet == 0 })
        #expect(state.players.allSatisfy { !$0.hasActed })
    }

    @Test("states without an actor do not keep a turn clock")
    func statesWithoutActorDoNotKeepTurnClock() {
        let state = GameState(
            handNumber: 1,
            players: makePlayers([100, 100]),
            dealerIndex: 0,
            smallBlind: 5,
            bigBlind: 10,
            board: [],
            deck: [],
            pot: 0,
            street: .preflop,
            currentToAct: nil,
            currentBet: 0,
            minRaise: 10,
            turnStartedAt: Date(),
            turnDuration: 30,
            results: nil,
            version: 0
        )

        #expect(state.turnStartedAt == nil)
    }

    @Test("current bet covers existing player bets")
    func currentBetCoversExistingPlayerBets() {
        var players = makePlayers([100, 100])
        players[0].bet = 40

        let state = GameState(
            handNumber: 1,
            players: players,
            dealerIndex: 0,
            smallBlind: 5,
            bigBlind: 10,
            board: [],
            deck: [],
            pot: 0,
            street: .preflop,
            currentToAct: 1,
            currentBet: 20,
            minRaise: 10,
            turnStartedAt: Date(),
            turnDuration: 30,
            results: nil,
            version: 0
        )

        #expect(state.currentBet == 40)
        #expect(state.legalActions(for: 1).callAmount == 40)
    }

    @Test("board cards are capped to holdem size")
    func boardCardsAreCappedToHoldemSize() {
        let state = GameState(
            handNumber: 1,
            players: makePlayers([100, 100]),
            dealerIndex: 0,
            smallBlind: 5,
            bigBlind: 10,
            board: cards("Ah Kh Qh Jh Th 9h"),
            deck: [],
            pot: 0,
            street: .river,
            currentToAct: nil,
            currentBet: 0,
            minRaise: 10,
            turnStartedAt: nil,
            turnDuration: 30,
            results: nil,
            version: 0
        )

        #expect(state.board == cards("Ah Kh Qh Jh Th"))
    }

    @Test("deck keeps only unique undealt cards")
    func deckKeepsOnlyUniqueUndealtCards() {
        var players = makePlayers([100, 100])
        players[0].holeCards = cards("Ah Kh")
        players[1].holeCards = cards("Qh Jh")

        let state = GameState(
            handNumber: 1,
            players: players,
            dealerIndex: 0,
            smallBlind: 5,
            bigBlind: 10,
            board: cards("Th 9h 8h"),
            deck: cards("Ah 7h 7h Th 6h Qh 5h"),
            pot: 0,
            street: .flop,
            currentToAct: nil,
            currentBet: 0,
            minRaise: 10,
            turnStartedAt: nil,
            turnDuration: 30,
            results: nil,
            version: 0
        )

        #expect(state.deck == cards("7h 6h 5h"))
    }

    @Test("visible cards are unique across seats and board")
    func visibleCardsAreUniqueAcrossSeatsAndBoard() {
        var players = makePlayers([100, 100])
        players[0].holeCards = cards("Ah Kh")
        players[1].holeCards = cards("Ah Qh Kh")

        let state = GameState(
            handNumber: 1,
            players: players,
            dealerIndex: 0,
            smallBlind: 5,
            bigBlind: 10,
            board: cards("Qh Jh Ah Jh Th 9h"),
            deck: cards("Qh 8h Jh 7h"),
            pot: 0,
            street: .flop,
            currentToAct: nil,
            currentBet: 0,
            minRaise: 10,
            turnStartedAt: nil,
            turnDuration: 30,
            results: nil,
            version: 0
        )

        #expect(state.players[0].holeCards == cards("Ah Kh"))
        #expect(state.players[1].holeCards == cards("Qh"))
        #expect(state.board == cards("Jh Th 9h"))
        #expect(state.deck == cards("8h 7h"))
    }

    @Test("results are limited to current players")
    func resultsAreLimitedToCurrentPlayers() {
        let state = GameState(
            handNumber: 1,
            players: makePlayers([100, 100]),
            dealerIndex: 0,
            smallBlind: 5,
            bigBlind: 10,
            board: [],
            deck: [],
            pot: 0,
            street: .showdown,
            currentToAct: nil,
            currentBet: 0,
            minRaise: 10,
            turnStartedAt: nil,
            turnDuration: 30,
            results: [
                HandResult(playerID: "", amountWon: 30, handName: nil, bestFive: nil),
                HandResult(playerID: "missing", amountWon: 20, handName: nil, bestFive: nil),
                HandResult(playerID: "p1", amountWon: -10, handName: nil, bestFive: nil),
            ],
            version: 0
        )

        #expect(state.results?.map(\.playerID) == ["p1"])
        #expect(state.results?.first?.amountWon == 0)
    }

    @Test("duplicate result rows are merged by player")
    func duplicateResultRowsAreMergedByPlayer() {
        let state = GameState(
            handNumber: 1,
            players: makePlayers([100, 100]),
            dealerIndex: 0,
            smallBlind: 5,
            bigBlind: 10,
            board: [],
            deck: [],
            pot: 0,
            street: .showdown,
            currentToAct: nil,
            currentBet: 0,
            minRaise: 10,
            turnStartedAt: nil,
            turnDuration: 30,
            results: [
                HandResult(playerID: "p1", amountWon: 10, handName: "Pair", bestFive: nil),
                HandResult(playerID: "p0", amountWon: 5, handName: nil, bestFive: nil),
                HandResult(playerID: "p1", amountWon: 20, handName: "Flush", bestFive: nil),
            ],
            version: 0
        )

        #expect(state.results?.map(\.playerID) == ["p1", "p0"])
        #expect(state.results?.map(\.amountWon) == [30, 5])
        #expect(state.results?.first?.handName == "Pair")
    }
}
