import Testing
@testable import GameCore

@Suite("HandEvaluator partial hands")
struct PartialHandTests {
    @Test("empty card lists do not produce a rank")
    func emptyCardListsDoNotProduceRank() {
        #expect(HandEvaluator.evaluateIfPossible([]) == nil)
    }

    @Test("preflop pocket pair is a pair")
    func pocketPair() {
        let r = eval("As Ah")
        #expect(r.category == .pair)
        #expect(r.tiebreakers.first == 14)
    }

    @Test("preflop offsuit is high card")
    func preflopHighCard() {
        let r = eval("2d 6h")
        #expect(r.category == .highCard)
        #expect(r.tiebreakers == [6, 2])
    }

    @Test("partial suited connectors are not flushes or straights")
    func partialSuitedConnectors() {
        let r = eval("5h 6h 7h 8h")
        #expect(r.category == .highCard)
        #expect(r.tiebreakers == [8, 7, 6, 5])
    }
}
