import Foundation
import GameCore

extension RenderScenarios {
    /// A flop with a live bet on the table, so the amber chips are visible.
    static func flopWithBet() -> GameState {
        var state = GameState.startHand(players: samplePlayers(), dealerIndex: 3,
                                        smallBlind: 5, bigBlind: 10,
                                        seed: 21, handNumber: 4)
        checkOrCallWhilePreflop(&state)
        if state.street == .flop, let index = state.currentToAct {
            state.apply(.raise(to: 20), by: index)
        }
        return state
    }

    /// Hero is the player to act: shows the action bar + bet chips.
    static func actingState() -> (GameState, String) {
        let state = flopWithBet()
        let heroID = state.currentPlayer?.id ?? "dante"
        return (state, heroID)
    }

    /// Hero is waiting on someone else: shows an opponent's live countdown pie.
    static func waitingState() -> (GameState, String) {
        var state = flopWithBet()
        state.turnStartedAt = Date().addingTimeInterval(-12)
        let activeID = state.currentPlayer?.id
        let heroID = state.players.first { $0.id != activeID && $0.isContesting }?.id ?? "dante"
        return (state, heroID)
    }

    static func showdownState() -> (GameState, String) {
        var state = GameState.startHand(players: samplePlayers(), dealerIndex: 3,
                                        smallBlind: 5, bigBlind: 10,
                                        seed: 8, handNumber: 4)
        checkOrCallToHandEnd(&state)
        let heroID = state.results?.first { $0.amountWon > 0 }?.playerID ?? "dante"
        return (state, heroID)
    }

    static func heroBetState() -> GameState {
        GameState.startHand(players: samplePlayers(), dealerIndex: 3,
                            smallBlind: 5, bigBlind: 10, seed: 21, handNumber: 4)
    }

    static func sixPlayerState() -> (GameState, String) {
        let state = GameState.startHand(players: sixPlayers(), dealerIndex: 3,
                                        smallBlind: 5, bigBlind: 10,
                                        seed: 21, handNumber: 1)
        let heroID = state.currentPlayer?.id ?? "p0"
        return (state, heroID)
    }

    private static func checkOrCallWhilePreflop(_ state: inout GameState) {
        var guardCount = 0
        while state.street == .preflop, let index = state.currentToAct, guardCount < 30 {
            checkOrCall(&state, by: index)
            guardCount += 1
        }
    }

    private static func checkOrCallToHandEnd(_ state: inout GameState) {
        var guardCount = 0
        while let index = state.currentToAct, guardCount < 200 {
            checkOrCall(&state, by: index)
            guardCount += 1
        }
    }

    private static func checkOrCall(_ state: inout GameState, by index: Int) {
        let legal = state.legalActions(for: index)
        state.apply(legal.canCheck ? .check : .call, by: index)
    }
}
