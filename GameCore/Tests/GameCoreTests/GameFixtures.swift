import GameCore
import Foundation

func makePlayers(_ stacks: [Int]) -> [Player] {
    stacks.enumerated().map { i, stack in
        Player(id: "p\(i)", name: "P\(i)", avatar: "🙂", stack: stack)
    }
}

func sixPlayerState() -> GameState {
    let players = (0..<6).map {
        Player(id: "user-\($0)", name: "player_\($0)", avatar: "🙂", stack: 1000)
    }
    let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)
    return GameState.startHand(players: players, dealerIndex: 0,
                               smallBlind: 10, bigBlind: 20,
                               seed: 99, handNumber: 3, now: fixedNow)
}

func headsUpTableMessage() -> TableMessage {
    let players = [
        Player(id: "a", name: "Alice", avatar: "A", stack: 1000),
        Player(id: "b", name: "Bob", avatar: "B", stack: 1000),
    ]
    return .game(GameState.startHand(players: players, dealerIndex: 0,
                                     smallBlind: 10, bigBlind: 20,
                                     seed: 1, handNumber: 1,
                                     tableID: "table-123"))
}
