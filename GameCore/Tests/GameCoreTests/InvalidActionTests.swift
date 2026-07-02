import Testing
@testable import GameCore

@Suite("Invalid actions")
struct InvalidActionTests {
    @Test("applying with an invalid player index leaves the hand unchanged")
    func applyingInvalidIndexIsNoop() {
        var s = GameState.startHand(players: makePlayers([1000, 1000]),
                                    dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                    seed: 1, handNumber: 1)
        let before = s

        let didApply = s.apply(.fold, by: 99)

        #expect(didApply == false)
        #expect(s == before)
    }

    @Test("direct apply reports whether an action changed the hand")
    func applyReportsMutation() {
        var s = GameState.startHand(players: makePlayers([1000, 1000]),
                                    dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                    seed: 1, handNumber: 1)

        #expect(s.apply(.check, by: 0) == false)
        #expect(s.apply(.fold, by: 0) == true)
    }

    @Test("direct apply rejects call when checking is free")
    func applyRejectsCallWhenCheckingIsFree() {
        var s = GameState.startHand(players: makePlayers([1000, 1000]),
                                    dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                    seed: 1, handNumber: 1)

        #expect(s.apply(.call, by: 0) == true)
        let before = s

        #expect(s.apply(.call, by: 1) == false)
        #expect(s == before)
    }

    @Test("completed hands do not expose or accept player actions")
    func completedHandRejectsActions() {
        var s = GameState.startHand(players: makePlayers([1000, 1000]),
                                    dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                    seed: 1, handNumber: 1)
        s.results = [HandResult(playerID: "p1", amountWon: 30,
                                handName: nil, bestFive: nil)]
        let before = s

        #expect(s.legalActions(for: 0) == .empty)
        #expect(s.apply(.fold, by: 0) == false)
        #expect(s == before)
    }

    @Test("legal actions for an invalid player index are empty")
    func legalActionsForInvalidIndexAreEmpty() {
        let s = GameState.startHand(players: makePlayers([1000, 1000]),
                                    dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                    seed: 1, handNumber: 1)

        let legal = s.legalActions(for: -1)

        #expect(legal == LegalActions.empty)
    }

    @Test("empty legal actions report no available action")
    func emptyLegalActionsReportNoAvailableAction() {
        let legal = LegalActions.empty

        #expect(!legal.hasAvailableAction)
    }

    @Test("legal actions for non-actable players are empty")
    func legalActionsForNonActablePlayersAreEmpty() {
        var folded = GameState.startHand(players: makePlayers([1000, 1000]),
                                         dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                         seed: 1, handNumber: 1)
        folded.players[0].status = .folded

        var allIn = GameState.startHand(players: makePlayers([20, 1000]),
                                        dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                        seed: 1, handNumber: 1)
        allIn.players[0].status = .allIn

        #expect(folded.legalActions(for: 0) == .empty)
        #expect(allIn.legalActions(for: 0) == .empty)
    }

    @Test("legal actions for an active non-current player are empty")
    func legalActionsForNonCurrentPlayerAreEmpty() {
        let s = GameState.startHand(players: makePlayers([1000, 1000, 1000]),
                                    dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                    seed: 1, handNumber: 1)

        #expect(s.currentToAct == 0)
        #expect(s.legalActions(for: 1) == .empty)
    }
}
