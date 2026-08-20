import Testing
@testable import GameCore

@Suite("Hand evaluator")
struct HandEvaluatorTests {
    @Test("detects each category")
    func categories() {
        #expect(eval("Ah Kh Qh Jh Th").category == .straightFlush)
        #expect(eval("9s 9h 9d 9c 2s").category == .fourOfAKind)
        #expect(eval("Kd Kh Ks 7c 7d").category == .fullHouse)
        #expect(eval("2h 7h 9h Jh Kh").category == .flush)
        #expect(eval("5d 6c 7h 8s 9d").category == .straight)
        #expect(eval("Qd Qh Qs 4c 9d").category == .threeOfAKind)
        #expect(eval("Jd Jh 4s 4c 9d").category == .twoPair)
        #expect(eval("Ad Ah 4s 7c 9d").category == .pair)
        #expect(eval("Ad Kh 9s 7c 4d").category == .highCard)
    }

    @Test("category strength is ordered")
    func categoryOrder() {
        #expect(eval("Ah Kh Qh Jh Th") > eval("9s 9h 9d 9c 2s"))
        #expect(eval("9s 9h 9d 9c 2s") > eval("Kd Kh Ks 7c 7d"))
        #expect(eval("Kd Kh Ks 7c 7d") > eval("2h 7h 9h Jh Kh"))
        #expect(eval("2h 7h 9h Jh Kh") > eval("5d 6c 7h 8s 9d"))
        #expect(eval("5d 6c 7h 8s 9d") > eval("Qd Qh Qs 4c 9d"))
        #expect(eval("Qd Qh Qs 4c 9d") > eval("Jd Jh 4s 4c 9d"))
        #expect(eval("Jd Jh 4s 4c 9d") > eval("Ad Ah 4s 7c 9d"))
        #expect(eval("Ad Ah 4s 7c 9d") > eval("Ad Kh 9s 7c 4d"))
    }

    @Test("kickers order equal categories and suits do not")
    func kickerOrderingAndSuitTies() {
        #expect(eval("Kd Kh Ah 5s 3c") > eval("Ks Kc Qh 5d 3h"))
        #expect(eval("Ad Kh 9s 7c 5d") > eval("Ad Kh 9s 7c 4d"))
        #expect(eval("Ad Ah 4s 7c 9d") == eval("Ac As 4d 7h 9c"))
    }

    @Test("wheel straight is five-high")
    func wheel() {
        let wheel = eval("Ad 2c 3h 4s 5d")
        #expect(wheel.category == .straight)
        #expect(wheel.tiebreakers == [5])
        #expect(eval("2c 3h 4s 5d 6c") > wheel)
    }

    @Test("full houses compare trips before pairs")
    func fullHouseTiebreakers() {
        let kingsFull = eval("Kd Kh Ks 7c 7d")
        let queensFull = eval("Qd Qh Qs Ac Ad")
        #expect(kingsFull.tiebreakers == [13, 7])
        #expect(kingsFull > queensFull)
    }

    @Test("royal flush names itself")
    func royal() {
        #expect(eval("As Ks Qs Js Ts").name == "Royal Flush")
        #expect(eval("9s 8s 7s 6s 5s").name == "Straight Flush")
    }

    @Test("best of seven selects the strongest five cards")
    func bestOfSeven() {
        let twoPair = eval("5d 8c 8h 5s 2d 6h")
        #expect(twoPair.category == .twoPair)
        #expect(twoPair.tiebreakers == [8, 5, 6])

        let flush = eval("6c Jh 2c 8h 7c 4c Jc")
        #expect(flush.category == .flush)
        #expect(flush.bestFive.count == 5)
        #expect(flush.bestFive.allSatisfy { $0.suit == .clubs })
        #expect(flush > eval("6c Jh 2c 8h 7c 2s 8s"))

    }

    @Test("partial hands are ranked without inventing made hands")
    func partialHands() {
        #expect(HandEvaluator.evaluateIfPossible([]) == nil)

        let pair = eval("As Ah")
        #expect(pair.category == .pair)
        #expect(pair.tiebreakers.first == 14)

        let highCard = eval("2d 6h")
        #expect(highCard.category == .highCard)
        #expect(highCard.tiebreakers == [6, 2])

        let connectors = eval("5h 6h 7h 8h")
        #expect(connectors.category == .highCard)
        #expect(connectors.tiebreakers == [8, 7, 6, 5])
    }
}
