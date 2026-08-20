public enum Rank: Int, Codable, Comparable, Sendable {
    case two = 2, three, four, five, six, seven, eight, nine, ten, jack, queen, king, ace

    public static func < (lhs: Rank, rhs: Rank) -> Bool { lhs.rawValue < rhs.rawValue }

    /// Label drawn on the card face.
    public var label: String {
        switch self {
        case .ten: return "10"
        case .jack: return "J"
        case .queen: return "Q"
        case .king: return "K"
        case .ace: return "A"
        default: return String(rawValue)
        }
    }
}

public enum Suit: Int, Codable, CaseIterable, Sendable {
    case clubs = 0, diamonds, hearts, spades

    public var isRed: Bool { self == .diamonds || self == .hearts }

    /// Glyph used on the card face in the UI.
    public var symbol: String {
        switch self {
        case .clubs: return "\u{2663}"
        case .diamonds: return "\u{2666}"
        case .hearts: return "\u{2665}"
        case .spades: return "\u{2660}"
        }
    }
}

/// A playing card.
public struct Card: Hashable, Comparable, Sendable, Codable {
    public let rank: Rank
    public let suit: Suit

    public init(rank: Rank, suit: Suit) {
        self.rank = rank
        self.suit = suit
    }

    /// 0...51, ordered by rank then suit. Lets a card travel as one small integer.
    public var code: Int {
        (rank.rawValue - Rank.two.rawValue) * Suit.allCases.count + suit.rawValue
    }

    public init?(code: Int) {
        guard (0...51).contains(code) else { return nil }
        let suitsPerRank = Suit.allCases.count
        guard let rank = Rank(rawValue: code / suitsPerRank + Rank.two.rawValue),
              let suit = Suit(rawValue: code % suitsPerRank) else { return nil }
        self.init(rank: rank, suit: suit)
    }

    public static func < (lhs: Card, rhs: Card) -> Bool { lhs.code < rhs.code }

    // Compact wire format: a card is its integer code.
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(Int.self)
        guard let card = Card(code: value) else {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Invalid card code \(value)")
        }
        self = card
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(code)
    }

    static var fullDeck: [Card] { (0...51).compactMap(Card.init(code:)) }

    static func shuffledDeck(seed: UInt64) -> [Card] {
        var deck = fullDeck
        var rng = SplitMix64(seed: seed)
        deck.shuffle(using: &rng)
        return deck
    }
}

private struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}

extension Array where Element == Card {
    mutating func dealTopIfAvailable() -> Card? {
        guard !isEmpty else { return nil }
        return removeFirst()
    }

    mutating func dealTopIfAvailable(_ count: Int) -> [Card] {
        let dealCount = Swift.min(Swift.max(0, count), self.count)
        let dealt = Array(prefix(dealCount))
        removeFirst(dealCount)
        return dealt
    }
}
