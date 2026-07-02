enum FiveCardHandEvaluator {
    /// Ranks 1-5 cards directly. Straights/flushes/full houses require 5 cards;
    /// fewer cards can only form high card / pair / two pair / trips / quads,
    /// which is what the live "current hand" indicator needs pre-river.
    static func evaluate(_ cards: [Card]) -> HandRank {
        precondition((1...5).contains(cards.count))
        let features = HandFeatures(cards: cards)
        let classification = HandClassification(features: features)
        return HandRank(category: classification.category,
                        tiebreakers: classification.tiebreakers,
                        bestFive: features.bestFive)
    }
}
