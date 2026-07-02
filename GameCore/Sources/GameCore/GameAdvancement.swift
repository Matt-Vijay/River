import Foundation

extension GameState {
    mutating func advance(now: Date) {
        if contenders.count <= 1 {
            awardUncontested()
            return
        }

        let actable = players.indices.filter { players[$0].status == .active }
        let everyoneMatched = actable.allSatisfy { players[$0].hasActed && players[$0].bet == currentBet }

        if !actable.isEmpty && !everyoneMatched {
            if let next = nextSeat(after: currentToAct ?? dealerIndex, where: { $0.canAct }) {
                currentToAct = next
                turnStartedAt = now
            }
            return
        }

        collectBets()

        if actable.count <= 1 {
            runOutAndShowdown()
            return
        }

        guard street != .river else {
            goToShowdown()
            return
        }

        advanceStreet(now: now)
    }
}
