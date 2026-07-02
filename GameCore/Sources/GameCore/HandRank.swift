/// The strength of a poker hand: a category plus tiebreaker rank values
/// (most significant first), and the exact cards that form it.
///
/// Comparison ignores `bestFive` — two hands of equal category and tiebreakers
/// tie (split pot), regardless of suits.
public struct HandRank: Comparable, Sendable {
    public let category: HandCategory
    public let tiebreakers: [Int]
    public let bestFive: [Card]

    public var name: String {
        if category == .straightFlush, tiebreakers.first == Rank.ace.rawValue {
            return "Royal Flush"
        }
        return category.name
    }

    public static func == (lhs: HandRank, rhs: HandRank) -> Bool {
        lhs.category == rhs.category && lhs.tiebreakers == rhs.tiebreakers
    }

    public static func < (lhs: HandRank, rhs: HandRank) -> Bool {
        if lhs.category != rhs.category { return lhs.category < rhs.category }
        for (a, b) in zip(lhs.tiebreakers, rhs.tiebreakers) where a != b {
            return a < b
        }
        return lhs.tiebreakers.count < rhs.tiebreakers.count
    }
}
