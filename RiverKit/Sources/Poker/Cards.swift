import Foundation

public enum Suit: Int, Codable, Sendable {
    case clubs, diamonds, hearts, spades

    public var symbol: String { ["\u{2663}", "\u{2666}", "\u{2665}", "\u{2660}"][rawValue] }
    public var name: String { ["clubs", "diamonds", "hearts", "spades"][rawValue] }
    public var isRed: Bool { self == .diamonds || self == .hearts }
}

public struct Card: Hashable, Comparable, Codable, Sendable, Identifiable {
    public let id: Int
    public var rank: Int { id / 4 + 2 }
    public var suit: Suit { Suit(rawValue: id % 4)! }
    public var label: String { rank < 11 ? String(rank) : ["J", "Q", "K", "A"][rank - 11] }
    public var spoken: String {
        let name = rank < 11 ? String(rank) : ["Jack", "Queen", "King", "Ace"][rank - 11]
        return "\(name) of \(suit.name)"
    }

    public init?(id: Int) {
        guard (0..<52).contains(id) else { return nil }
        self.id = id
    }

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.id < rhs.id }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        guard let card = Card(id: try container.decode(Int.self)) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid card")
        }
        self = card
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(id)
    }

    static func deck(seed: UInt64) -> [Card] {
        var cards = (0..<52).compactMap(Card.init(id:))
        var random = SplitMix64(state: seed)
        // Explicit Fisher-Yates keeps seeded deals independent of Swift's shuffle implementation.
        for index in stride(from: cards.count - 1, through: 1, by: -1) {
            let bound = UInt64(index + 1)
            let threshold = (0 &- bound) % bound
            var value = random.next()
            while value < threshold { value = random.next() }
            cards.swapAt(index, Int(value % bound))
        }
        return cards
    }
}

private struct SplitMix64 {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}

public struct HandValue: Comparable, Sendable {
    public enum Category: Int, Comparable, Sendable {
        case highCard, pair, twoPair, threeOfAKind, straight, flush, fullHouse, fourOfAKind, straightFlush
        public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
        public var name: String {
            ["High card", "Pair", "Two pair", "Three of a kind", "Straight", "Flush",
             "Full house", "Four of a kind", "Straight flush"][rawValue]
        }
    }

    public let category: Category
    public let ranks: [Int]
    public let cards: [Card]
    public var name: String { category == .straightFlush && ranks == [14] ? "Royal flush" : category.name }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.category == rhs.category && lhs.ranks == rhs.ranks
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.category == rhs.category
            ? lhs.ranks.lexicographicallyPrecedes(rhs.ranks) : lhs.category < rhs.category
    }

    public static func best(_ cards: [Card]) -> HandValue? {
        guard (1...7).contains(cards.count), Set(cards).count == cards.count else { return nil }
        if cards.count <= 5 { return rank(cards) }
        var best: HandValue?
        for a in 0..<(cards.count - 4) {
            for b in (a + 1)..<(cards.count - 3) {
                for c in (b + 1)..<(cards.count - 2) {
                    for d in (c + 1)..<(cards.count - 1) {
                        for e in (d + 1)..<cards.count {
                            let candidate = rank([cards[a], cards[b], cards[c], cards[d], cards[e]])
                            if best == nil || candidate > best!
                                || (candidate == best! && best!.cards.lexicographicallyPrecedes(candidate.cards)) {
                                best = candidate
                            }
                        }
                    }
                }
            }
        }
        return best
    }

    private static func rank(_ cards: [Card]) -> HandValue {
        var counts = [Int](repeating: 0, count: 15)
        for card in cards { counts[card.rank] += 1 }
        let groups: [(rank: Int, count: Int)] = (2...14).filter { counts[$0] > 0 }
            .map { (rank: $0, count: counts[$0]) }
            .sorted { $0.count == $1.count ? $0.rank > $1.rank : $0.count > $1.count }
        let ranks = groups.map(\.rank)
        let flush = cards.count == 5 && cards.allSatisfy { $0.suit == cards[0].suit }
        let straight: Int? = ranks == [14, 5, 4, 3, 2] ? 5
            : ranks.count == 5 && ranks[0] - ranks[4] == 4 ? ranks[0] : nil
        let category: Category
        if flush && straight != nil { category = .straightFlush }
        else if groups[0].count == 4 { category = .fourOfAKind }
        else if groups[0].count == 3 && groups.count == 2 && groups[1].count == 2 { category = .fullHouse }
        else if flush { category = .flush }
        else if straight != nil { category = .straight }
        else if groups[0].count == 3 { category = .threeOfAKind }
        else if groups[0].count == 2 && groups.count > 1 && groups[1].count == 2 { category = .twoPair }
        else if groups[0].count == 2 { category = .pair }
        else { category = .highCard }
        return HandValue(category: category, ranks: straight.map { [$0] } ?? ranks,
                         cards: cards.sorted(by: >))
    }
}
