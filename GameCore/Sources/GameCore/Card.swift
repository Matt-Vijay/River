/// A playing card.
public struct Card: Hashable, Comparable, Sendable, CustomStringConvertible, Codable {
    public let rank: Rank
    public let suit: Suit

    public init(rank: Rank, suit: Suit) {
        self.rank = rank
        self.suit = suit
    }

    /// 0...51, ordered by rank then suit. Lets a card travel as one small integer.
    public var code: Int { (rank.rawValue - 2) * Suit.allCases.count + suit.rawValue }

    public init?(code: Int) {
        guard (0...51).contains(code) else { return nil }
        guard let rank = Rank(rawValue: code / 4 + 2),
              let suit = Suit(rawValue: code % 4) else { return nil }
        self.init(rank: rank, suit: suit)
    }

    public static func < (lhs: Card, rhs: Card) -> Bool { lhs.code < rhs.code }

    public var description: String { rank.shortLabel + suit.letter }
}
