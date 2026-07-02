extension GameState {
    public func legalActions(for index: Int) -> LegalActions {
        guard !isHandComplete else { return .empty }
        guard players.indices.contains(index) else { return .empty }
        guard isCurrentPlayer(at: index) else { return .empty }

        let player = players[index]
        guard player.canAct else { return .empty }

        let toCall = max(0, currentBet - player.bet)
        let callAmount = min(toCall, player.stack)
        let raiseBounds = raiseBounds(for: player, toCall: toCall)

        return LegalActions(
            canFold: true,
            canCheck: toCall == 0,
            canCall: toCall > 0,
            callAmount: callAmount,
            currentBet: currentBet,
            canRaise: raiseBounds.canRaise,
            minRaiseTo: raiseBounds.min,
            maxRaiseTo: raiseBounds.max
        )
    }

    private func raiseBounds(for player: Player, toCall: Int) -> (canRaise: Bool, min: Int, max: Int) {
        let maxRaiseTo = player.bet + player.stack
        let canRaise = maxRaiseTo > currentBet && player.stack > toCall
        return (
            canRaise: canRaise,
            min: min(currentBet + minRaise, maxRaiseTo),
            max: maxRaiseTo
        )
    }
}
