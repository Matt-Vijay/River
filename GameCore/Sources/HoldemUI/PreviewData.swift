import SwiftUI
import GameCore

enum PreviewStates {
    static func players() -> [Player] {
        [
            Player(id: "dante", name: "dante", avatar: "🧑🏿", stack: 1000),
            Player(id: "merry", name: "merry_ti", avatar: "🧑🏾", stack: 266),
            Player(id: "jsven", name: "jsven", avatar: "🧑🏻", stack: 138),
            Player(id: "great", name: "great_e", avatar: "🧑🏽", stack: 1552),
            Player(id: "verbice", name: "verbice", avatar: "🐱", stack: 408),
        ]
    }

    /// Fresh preflop hand; the current actor is the hero (shows the action bar).
    static func preflopActing() -> (GameState, String) {
        let s = GameState.startHand(players: players(), dealerIndex: 3,
                                    smallBlind: 5, bigBlind: 10, seed: 21, handNumber: 4)
        let heroID = s.currentPlayer?.id ?? "dante"
        return (s, heroID)
    }

    /// A hand played out to showdown (full board, winner highlighted).
    static func showdown() -> (GameState, String) {
        var s = GameState.startHand(players: players(), dealerIndex: 3,
                                    smallBlind: 5, bigBlind: 10, seed: 8, handNumber: 4)
        var guardCount = 0
        while let i = s.currentToAct, guardCount < 200 {
            let legal = s.legalActions(for: i)
            s.apply(legal.canCheck ? .check : .call, by: i)
            guardCount += 1
        }
        let heroID = s.results?.first { $0.amountWon > 0 }?.playerID ?? "dante"
        return (s, heroID)
    }
}

#Preview("Table – acting") {
    let (state, hero) = PreviewStates.preflopActing()
    return PokerTableView(state: state, heroID: hero)
}

#Preview("Table – showdown") {
    let (state, hero) = PreviewStates.showdown()
    return PokerTableView(state: state, heroID: hero)
}
