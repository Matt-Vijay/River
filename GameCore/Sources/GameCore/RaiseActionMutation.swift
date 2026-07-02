extension GameState {
    mutating func raisePlayer(at index: Int, to requestedTotal: Int) -> Bool {
        let legal = legalActions(for: index)
        guard legal.canRaise else { return false }
        guard requestedTotal >= legal.minRaiseTo, requestedTotal <= legal.maxRaiseTo else {
            return false
        }

        let target = requestedTotal
        let oldBet = currentBet
        pay(index, additional: target - players[index].bet)
        let raiseSize = target - oldBet
        currentBet = max(currentBet, target)
        players[index].hasActed = true
        players[index].lastAction = .raise(to: target)

        if raiseSize >= minRaise {
            minRaise = raiseSize
            reopenAction(afterRaiseBy: index)
        }
        return true
    }

    private mutating func reopenAction(afterRaiseBy raiserIndex: Int) {
        for index in players.indices where players[index].status == .active && index != raiserIndex {
            players[index].hasActed = false
        }
    }
}
