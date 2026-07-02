extension GameState {
    /// The player's current best hand from their hole cards plus the visible
    /// board - powers the "Pair / Two Pair / Flush" indicator.
    public func currentHandRank(for index: Int) -> HandRank? {
        guard players.indices.contains(index) else { return nil }
        let cards = players[index].holeCards + board
        return HandEvaluator.evaluateIfPossible(cards)
    }
}
