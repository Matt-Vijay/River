import Foundation
import Testing
@testable import GameCore

@Suite("Card")
struct CardTests {
    @Test("code round-trips for all 52 cards")
    func codeRoundTrip() {
        for code in 0...51 {
            let card = Card(code: code)
            #expect(card != nil)
            #expect(card?.code == code)
        }
        #expect(Card(code: -1) == nil)
        #expect(Card(code: 52) == nil)
    }

    @Test("codes are unique across a full deck")
    func uniqueCodes() {
        let codes = Deck().cards.map(\.code)
        #expect(Set(codes).count == 52)
        #expect(codes.min() == 0)
        #expect(codes.max() == 51)
    }

    @Test("ordering is by rank then suit")
    func ordering() {
        #expect(Card(rank: .two, suit: .clubs) < Card(rank: .two, suit: .spades))
        #expect(Card(rank: .two, suit: .spades) < Card(rank: .three, suit: .clubs))
        #expect(Card(rank: .king, suit: .clubs) < Card(rank: .ace, suit: .clubs))
    }

    @Test("Codable encodes a card as a single integer")
    func compactCodable() throws {
        let card = Card(rank: .ace, suit: .spades)
        let data = try JSONEncoder().encode(card)
        #expect(String(data: data, encoding: .utf8) == "51")
        let decoded = try JSONDecoder().decode(Card.self, from: data)
        #expect(decoded == card)
    }

    @Test("Codable rejects invalid card codes")
    func compactCodableRejectsInvalidCode() {
        let data = Data("52".utf8)

        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(Card.self, from: data)
        }
    }

    @Test("labels render as expected")
    func labels() {
        #expect(Card(rank: .ten, suit: .hearts).rank.label == "10")
        #expect(Card(rank: .jack, suit: .hearts).rank.label == "J")
        #expect(Card(rank: .ace, suit: .hearts).suit.isRed == true)
        #expect(Card(rank: .ace, suit: .clubs).suit.isRed == false)
    }
}
