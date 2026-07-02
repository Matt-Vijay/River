import Testing
@testable import GameCore

@Suite("HandEvaluator strength ordering")
struct HandOrderingTests {
    @Test("category beats lower category")
    func categoryOrder() {
        #expect(eval("Ah Kh Qh Jh Th") > eval("9s 9h 9d 9c 2s")) // SF > quads
        #expect(eval("9s 9h 9d 9c 2s") > eval("Kd Kh Ks 7c 7d")) // quads > full
        #expect(eval("Kd Kh Ks 7c 7d") > eval("2h 7h 9h Jh Kh")) // full > flush
        #expect(eval("2h 7h 9h Jh Kh") > eval("5d 6c 7h 8s 9d")) // flush > straight
        #expect(eval("5d 6c 7h 8s 9d") > eval("Qd Qh Qs 4c 9d")) // straight > trips
        #expect(eval("Qd Qh Qs 4c 9d") > eval("Jd Jh 4s 4c 9d")) // trips > two pair
        #expect(eval("Jd Jh 4s 4c 9d") > eval("Ad Ah 4s 7c 9d")) // two pair > pair
        #expect(eval("Ad Ah 4s 7c 9d") > eval("Ad Kh 9s 7c 4d")) // pair > high
    }

    @Test("kicker breaks ties within a category")
    func kickers() {
        #expect(eval("Kd Kh Ah 5s 3c") > eval("Ks Kc Qh 5d 3h")) // A kicker > Q kicker
        #expect(eval("Ad Kh 9s 7c 5d") > eval("Ad Kh 9s 7c 4d")) // high card last kicker
    }

    @Test("equal hands tie regardless of suit")
    func ties() {
        #expect(eval("Ad Ah 4s 7c 9d") == eval("Ac As 4d 7h 9c"))
    }
}
