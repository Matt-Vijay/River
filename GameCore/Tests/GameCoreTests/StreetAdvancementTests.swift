import Testing
@testable import GameCore

@Suite("Street advancement")
struct StreetAdvancementTests {
    @Test("street advancement deals flop turn and river card counts")
    func streetAdvancementDealsBoardCards() throws {
        var s = GameState.startHand(players: makePlayers([1000, 1000]),
                                    dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                    seed: 7, handNumber: 1)

        try completeCurrentBettingRound(&s)
        #expect(s.street == .flop)
        #expect(s.board.count == 3)
        #expect(s.players.allSatisfy { $0.lastActionBet == nil })

        try completeCurrentBettingRound(&s)
        #expect(s.street == .turn)
        #expect(s.board.count == 4)

        try completeCurrentBettingRound(&s)
        #expect(s.street == .river)
        #expect(s.board.count == 5)
    }

    @Test("postflop action begins left of the dealer")
    func postflopActionOrder() throws {
        var headsUp = GameState.startHand(players: makePlayers([1000, 1000]),
                                          dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                          seed: 7, handNumber: 1)
        try completeCurrentBettingRound(&headsUp)
        #expect(headsUp.street == .flop)
        #expect(headsUp.currentToAct == 1)

        var multiway = GameState.startHand(players: makePlayers([1000, 1000, 1000, 1000]),
                                           dealerIndex: 1, smallBlind: 10, bigBlind: 20,
                                           seed: 8, handNumber: 1)
        try completeCurrentBettingRound(&multiway)
        #expect(multiway.street == .flop)
        #expect(multiway.currentToAct == 2)
    }

    @Test("a non-actor leave runs out when only one player still has chips")
    func nonActorLeaveCanTriggerRunout() throws {
        var state = GameState.startHand(players: makePlayers([100, 100, 20]),
                                        dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                        seed: 9, handNumber: 1)
        #expect(state.players[2].status == .allIn)

        let dealerCalled = state.apply(.call, by: 0)
        let smallBlindCalled = state.apply(.call, by: 1)
        #expect(dealerCalled)
        #expect(smallBlindCalled)
        #expect(state.street == .flop)
        #expect(state.currentToAct == 1)

        let didLeave = state.playerLeaves(id: "p0")
        #expect(didLeave)
        #expect(state.isHandComplete)
        #expect(state.board.count == 5)
        #expect(state.currentToAct == nil)
        #expect(totalChips(state) == 220)
    }

    private func completeCurrentBettingRound(_ state: inout GameState) throws {
        let startingStreet = state.street
        var guardCount = 0
        while state.street == startingStreet, let index = state.currentToAct, guardCount < 20 {
            let legal = state.legalActions(for: index)
            state.apply(legal.canCheck ? .check : .call, by: index)
            guardCount += 1
        }
        #expect(state.street != startingStreet)
    }
}
