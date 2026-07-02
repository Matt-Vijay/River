import Testing
@testable import GameCore

@Suite("HandEvaluator categories")
struct HandCategoryTests {
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

    @Test("wheel straight is five-high")
    func wheel() {
        let r = eval("Ad 2c 3h 4s 5d")
        #expect(r.category == .straight)
        #expect(r.tiebreakers == [5])
        // Six-high straight beats the wheel.
        #expect(eval("2c 3h 4s 5d 6c") > r)
    }

    @Test("full house tiebreakers are trips rank then pair rank")
    func fullHouseTiebreakers() {
        let kingsFull = eval("Kd Kh Ks 7c 7d")
        let queensFull = eval("Qd Qh Qs Ac Ad")

        #expect(kingsFull.category == .fullHouse)
        #expect(kingsFull.tiebreakers == [13, 7])
        #expect(kingsFull > queensFull)
    }

    @Test("royal flush names itself")
    func royal() {
        #expect(eval("As Ks Qs Js Ts").name == "Royal Flush")
        #expect(eval("9s 8s 7s 6s 5s").name == "Straight Flush")
    }
}
