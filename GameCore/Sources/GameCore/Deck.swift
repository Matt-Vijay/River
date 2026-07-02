import Foundation

/// A 52-card deck. Deals from the top.
public struct Deck: Sendable {
    public private(set) var cards: [Card]

    /// Fresh deck in canonical order (2c...As).
    public init() {
        cards = (0...51).compactMap(Card.init(code:))
    }

    /// Deck shuffled deterministically from a seed.
    public static func shuffled(seed: UInt64) -> Deck {
        var deck = Deck()
        var rng = SplitMix64(seed: seed)
        deck.cards.shuffle(using: &rng)
        return deck
    }

    public var count: Int { cards.count }

    /// Removes and returns the top card.
    public mutating func deal() -> Card {
        dealIfAvailable()!
    }

    /// Removes and returns the top card when one is available.
    public mutating func dealIfAvailable() -> Card? {
        guard !cards.isEmpty else { return nil }
        return cards.removeFirst()
    }

    /// Removes and returns the top `n` cards.
    public mutating func deal(_ n: Int) -> [Card] {
        let count = min(max(0, n), cards.count)
        let dealt = Array(cards.prefix(count))
        cards.removeFirst(count)
        return dealt
    }
}
