import Testing
@testable import GameCore

@Suite("Deck")
struct DeckTests {
    @Test("fresh deck has 52 cards")
    func freshDeck() {
        #expect(Deck().count == 52)
    }

    @Test("same seed produces identical shuffle")
    func deterministicShuffle() {
        let a = Deck.shuffled(seed: 12345)
        let b = Deck.shuffled(seed: 12345)
        #expect(a.cards == b.cards)
    }

    @Test("different seeds produce different shuffles")
    func differentSeeds() {
        let a = Deck.shuffled(seed: 1)
        let b = Deck.shuffled(seed: 2)
        #expect(a.cards != b.cards)
    }

    @Test("shuffle preserves the full 52-card set")
    func shufflePreservesSet() {
        let shuffled = Deck.shuffled(seed: 999)
        #expect(Set(shuffled.cards) == Set(Deck().cards))
    }

    @Test("dealing removes cards from the top")
    func dealing() throws {
        var deck = Deck()
        let top = try #require(deck.cards.first)
        let dealt = deck.deal()
        #expect(dealt == top)
        #expect(deck.count == 51)

        let two = deck.deal(2)
        #expect(two.count == 2)
        #expect(deck.count == 49)
    }

    @Test("optional dealing returns nil from an empty deck")
    func optionalDealingReturnsNilFromEmptyDeck() throws {
        var deck = Deck()
        let top = try #require(deck.cards.first)

        #expect(deck.dealIfAvailable() == top)
        #expect(deck.deal(60).count == 51)
        #expect(deck.dealIfAvailable() == nil)
    }

    @Test("dealing more cards than remain returns the remaining deck")
    func overDealingReturnsRemainingDeck() {
        var deck = Deck()

        let dealt = deck.deal(60)

        #expect(dealt.count == 52)
        #expect(Set(dealt) == Set(Deck().cards))
        #expect(deck.count == 0)
    }

    @Test("card arrays can deal safely from malformed short decks")
    func safeArrayDealing() {
        var cards = cards("Ah")

        #expect(cards.dealTopIfAvailable() == Card(rank: .ace, suit: .hearts))
        #expect(cards.dealTopIfAvailable() == nil)
        #expect(cards.dealTopIfAvailable(3) == [])
    }
}
