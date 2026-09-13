import Testing
@testable import Poker

struct CardsTests {
    func cards(_ text: String) -> [Card] {
        text.split(separator: " ").map {
            let characters = Array($0)
            let rank = Array("23456789TJQKA").firstIndex(of: characters[0])!
            let suit = Array("cdhs").firstIndex(of: characters[1])!
            return Card(id: rank * 4 + suit)!
        }
    }

    @Test func categoriesAndTieBreakers() throws {
        let examples = ["Ac Kd 9h 7s 3c", "Ac Ad 9h 7s 3c", "Ac Ad 9h 9s 3c",
            "Ac Ad Ah 7s 3c", "Ac 2d 3h 4s 5c", "Ac Jc 9c 7c 3c", "Ac Ad Ah 7s 7c",
            "Ac Ad Ah As 3c", "Tc Jc Qc Kc Ac"]
        var previous: HandValue?
        for (index, text) in examples.enumerated() {
            let value = try #require(HandValue.best(cards(text)))
            #expect(value.category.rawValue == index)
            if let previous { #expect(value > previous) }
            previous = value
        }
        #expect(HandValue.best(cards("Ac 2d 3h 4s 5c"))!.ranks == [5])
        #expect(HandValue.best(cards("Ac Ad Kc Qc Jc 9h 9s"))!.ranks == [14, 9, 13])
        #expect(HandValue.best(cards("Ac Ad Ah Kc Kd Kh 2c"))!.ranks == [14, 13])
        #expect(HandValue.best(cards("Ac Ad Ah As Kc Qd 2c"))!.ranks == [14, 13])
        #expect(HandValue.best(cards("Ac Kc Qc Jc Tc 2d 3h"))!.name == "Royal flush")
        #expect(HandValue.best(cards("Ac Ad Kh Qs Jc"))! > HandValue.best(cards("Ah As Kc Qd Tc"))!)
        #expect(HandValue.best(cards("Ac Ad Kh Qs Jc")) == HandValue.best(cards("Ah As Kc Qd Jh")))
        #expect(HandValue.best(cards("Ac Ac")) == nil)
        let hand = cards("Ac Ad Kh Qs Jc 4d 5s")
        #expect(HandValue.best(hand)?.cards == HandValue.best(hand.reversed())?.cards)
    }

    @Test func stableUniqueDeck() {
        #expect(Card.deck(seed: 42) == Card.deck(seed: 42))
        #expect(Card.deck(seed: 42) != Card.deck(seed: 43))
        #expect(Set(Card.deck(seed: 42)).count == 52)
        #expect(Card(id: -1) == nil)
        #expect(Card(id: 52) == nil)
    }
}
