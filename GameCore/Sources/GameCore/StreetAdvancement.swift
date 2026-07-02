import Foundation

extension GameState {
    mutating func advanceStreet(now: Date) {
        switch street {
        case .preflop:
            street = .flop
            board.append(contentsOf: deck.dealTopIfAvailable(3))
        case .flop:
            street = .turn
            if let card = deck.dealTopIfAvailable() { board.append(card) }
        case .turn:
            street = .river
            if let card = deck.dealTopIfAvailable() { board.append(card) }
        case .river, .showdown:
            goToShowdown()
            return
        }
        currentToAct = firstActorAfterDealer
        turnStartedAt = now
    }
}
