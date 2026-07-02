import Testing
@testable import GameCore

@Suite("HandEvaluator best-of-seven (matches screenshots)")
struct BestOfSevenTests {
    @Test("turn board 5-8-8-5 with 2-6 hole is two pair, eights and fives")
    func twoPairFromScreenshot() {
        // Reference screenshot: board 5d 8c 8h 5s, hole 2d 6h -> "Two Pair".
        let r = eval("5d 8c 8h 5s 2d 6h")
        #expect(r.category == .twoPair)
        #expect(r.name == "Two Pair")
        #expect(r.tiebreakers == [8, 5, 6]) // eights and fives, six kicker
    }

    @Test("river board 6-J-2-8-7 with 4c Jc hole is a club flush")
    func flushFromScreenshot() {
        // Reference screenshot: board 6c Jh 2c 8h 7c, hole 4c Jc -> "Flush".
        let r = eval("6c Jh 2c 8h 7c 4c Jc")
        #expect(r.category == .flush)
        #expect(r.name == "Flush")
        #expect(r.bestFive.count == 5)
        #expect(r.bestFive.allSatisfy { $0.suit == .clubs })
    }

    @Test("the flush beats the opponent's two pair on that board")
    func flushBeatsTwoPair() {
        // Same board, opponent holds 2s 8s -> two pair (eights and twos).
        let flush = eval("6c Jh 2c 8h 7c 4c Jc")
        let twoPair = eval("6c Jh 2c 8h 7c 2s 8s")
        #expect(twoPair.category == .twoPair)
        #expect(flush > twoPair)
    }

    @Test("best five is exactly five cards")
    func bestFiveCount() {
        #expect(eval("Ah Kh Qh Jh Th 2c 3d").bestFive.count == 5)
        #expect(eval("Ah Kh Qh Jh Th 2c 3d").category == .straightFlush)
    }
}
