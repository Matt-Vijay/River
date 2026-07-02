import Foundation

public enum HandEvaluator {
    /// Best hand from 1 to 7 cards. With 6–7 cards, picks the best 5-card subset.
    public static func evaluate(_ cards: [Card]) -> HandRank {
        precondition(!cards.isEmpty, "Cannot evaluate an empty hand")
        if cards.count <= 5 { return FiveCardHandEvaluator.evaluate(cards) }

        let ranks = combinations(cards, choose: 5).map(FiveCardHandEvaluator.evaluate)
        guard let best = ranks.max() else {
            preconditionFailure("Cannot evaluate without a five-card combination")
        }
        return best
    }

    /// Best hand when enough card information is available.
    public static func evaluateIfPossible(_ cards: [Card]) -> HandRank? {
        guard !cards.isEmpty else { return nil }
        return evaluate(cards)
    }
}
