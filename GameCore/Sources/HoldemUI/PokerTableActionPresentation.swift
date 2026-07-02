import GameCore

extension PokerTablePresentation {
    var actionMode: ActionMode {
        if state.isGameOver { return .gameOver }
        if canHeroDealNext { return .dealNext }
        if isHeroTurn { return .act }
        return .wait
    }

    var canHeroDealNext: Bool {
        canDealNext && state.canDealNextHand(actorID: heroID)
    }

    var waitingText: String {
        if state.isHandComplete { return "Next hand coming up…" }
        if hero?.status == .folded { return "You folded — wait for the next hand" }
        if let currentPlayer = state.currentPlayer {
            return "Waiting for \(currentPlayer.name)…"
        }
        return "Waiting for the next action…"
    }

    var canHeroFold: Bool {
        guard isHeroTurn, let heroIndex else { return false }
        return state.legalActions(for: heroIndex).canFold
    }

    func legalActionsForHero() -> LegalActions? {
        guard isHeroTurn, let heroIndex else { return nil }
        let legal = state.legalActions(for: heroIndex)
        return legal.hasAvailableAction ? legal : nil
    }

    func lastActionLabel(for player: Player) -> String? {
        switch player.lastAction {
        case .fold: return "Fold"
        case .check: return "Check"
        case .call: return "Call"
        case .raise:
            return player.bet == state.currentBet && state.currentBet > state.bigBlind ? "Raise" : "Bet"
        case .none: return nil
        }
    }
}
