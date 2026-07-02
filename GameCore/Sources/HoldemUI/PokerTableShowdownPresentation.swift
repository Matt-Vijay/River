import GameCore

extension PokerTablePresentation {
    var isShowdownReveal: Bool {
        state.street == .showdown && (state.results?.contains { $0.handName != nil } ?? false)
    }

    var winningCards: Set<Card>? {
        guard isShowdownReveal, let results = state.results else { return nil }

        let cards = results
            .filter { $0.amountWon > 0 }
            .compactMap(\.bestFive)
            .flatMap { $0 }

        return cards.isEmpty ? nil : Set(cards)
    }

    var showdownHandLabel: String? {
        guard isShowdownReveal, let results = state.results else { return nil }

        return results
            .filter { $0.amountWon > 0 }
            .compactMap(\.handName)
            .first
    }

    func revealedCards(for player: Player) -> [Card]? {
        guard isShowdownReveal, player.isContesting, player.holeCards.count == 2 else { return nil }
        return player.holeCards
    }

    func didWin(_ player: Player) -> Bool {
        state.results?.contains { $0.playerID == player.id && $0.amountWon > 0 } ?? false
    }
}
