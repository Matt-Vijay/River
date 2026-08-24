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

        let wheelFlush = eval("As 2s 3s 4s 5s 9d Kh")
        #expect(wheelFlush.category == .straightFlush)
        #expect(wheelFlush.tiebreakers == [5])
        #expect(eval("As 2d 3h 4c 5s 6s Kh").tiebreakers == [6])
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

    @Test("every category carries its complete poker tie key")
    func completeTieKeys() {
        #expect(eval("As Kd 9c 7h 4s").tiebreakers == [14, 13, 9, 7, 4])
        #expect(eval("As Ad Kc Qh 9s").tiebreakers == [14, 13, 12, 9])
        #expect(eval("As Ad Kc Kh 9s").tiebreakers == [14, 13, 9])
        #expect(eval("As Ad Ac Kh 9s").tiebreakers == [14, 13, 9])
        #expect(eval("Ts Jd Qc Kh As").tiebreakers == [14])
        #expect(eval("As Ks 9s 7s 4s").tiebreakers == [14, 13, 9, 7, 4])
        #expect(eval("As Ad Ac Kh Ks").tiebreakers == [14, 13])
        #expect(eval("As Ad Ac Ah Ks").tiebreakers == [14, 13])
        #expect(eval("As Ks Qs Js Ts").tiebreakers == [14])
    }

    @Test("the final relevant kicker breaks every non-straight tie")
    func deepestKickers() {
        let comparisons = [
            ("As Kd 9c 7h 4s", "Ah Kc 9d 7s 3h"),
            ("As Ad Kc Qh 9s", "Ac Ah Kd Qs 8h"),
            ("As Ad Kc Kh 9s", "Ac Ah Kd Ks 8h"),
            ("As Ad Ac Kh 9s", "Ah As Ad Kc 8s"),
            ("As Js 9s 7s 4s", "Ah Jh 9h 7h 3h"),
            ("As Ad Ac Kh Ks", "Ah As Ad Qc Qs"),
            ("As Ad Ac Ah Ks", "As Ad Ac Ah Qs"),
        ]

        for (stronger, weaker) in comparisons {
            #expect(eval(stronger) > eval(weaker))
        }
    }

    @Test("the board can play and tied suits never choose a winner")
    func boardPlays() {
        let board = cards("Ah Kd Qc Js Th")
        let first = HandEvaluator.evaluate(cards("2c 3c") + board)
        let second = HandEvaluator.evaluate(cards("9h 9s") + board)

        #expect(first == second)
        #expect(first.category == .straight)
        #expect(Set(first.bestFive) == Set(board))
        #expect(Set(second.bestFive) == Set(board))

        let quadsBoard = cards("9c 9d 9h 9s 2c")
        let aceSpades = HandEvaluator.evaluate(cards("As Kd") + quadsBoard)
        let aceHearts = HandEvaluator.evaluate(cards("Ah Qd") + quadsBoard)
        #expect(aceSpades == aceHearts)
        #expect(aceSpades.tiebreakers == [9, 14])
    }

    @Test("multiple made combinations choose the highest complete rank")
    func competingCombinations() {
        let doubleTrips = eval("As Ah Ad Ks Kh Kd 2c")
        #expect(doubleTrips.category == .fullHouse)
        #expect(doubleTrips.tiebreakers == [14, 13])

        let threePairs = eval("As Ah Ks Kh Qs Qh 2c")
        #expect(threePairs.category == .twoPair)
        #expect(threePairs.tiebreakers == [14, 13, 12])

        let sixCardFlush = eval("As Js 9s 7s 4s 2s Kd")
        #expect(sixCardFlush.category == .flush)
        #expect(sixCardFlush.tiebreakers == [14, 11, 9, 7, 4])
        #expect(!sixCardFlush.bestFive.contains(Card(rank: .two, suit: .spades)))
    }

    @Test("equal-rank best-five metadata is canonical across card order")
    func canonicalBestFive() {
        let source = cards("As Ah Ad Ks Kh Kd 2c")
        let expected = HandEvaluator.evaluate(source)

        for offset in source.indices {
            let rotated = Array(source[offset...] + source[..<offset])
            let reversed = Array(rotated.reversed())
            #expect(HandEvaluator.evaluate(rotated).bestFive == expected.bestFive)
            #expect(HandEvaluator.evaluate(reversed).bestFive == expected.bestFive)
        }
    }

    @Test("best-of-seven agrees with an independent deterministic oracle sample")
    func referenceOracleSample() {
        var mismatch: String?

        for seed in UInt64(0)..<10_000 {
            let hand = Array(Card.shuffledDeck(seed: seed).prefix(7))
            let actual = HandEvaluator.evaluate(hand)
            let actualKey = [actual.category.rawValue] + actual.tiebreakers
            let expectedKey = referenceBestKey(hand)
            if actualKey != expectedKey {
                mismatch = "seed=\(seed), actual=\(actualKey), expected=\(expectedKey)"
                break
            }
        }

        #expect(mismatch == nil)
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

/// A deliberately separate five-card implementation used as a regression oracle.
/// It does not share the production evaluator's feature extraction or branching.
private func referenceBestKey(_ cards: [Card]) -> [Int] {
    precondition((5...7).contains(cards.count))
    var best: [Int]?
    var selection: [Card] = []

    func visit(_ start: Int) {
        if selection.count == 5 {
            let candidate = referenceFiveKey(selection)
            if best == nil || lexicographicallyLess(best!, candidate) {
                best = candidate
            }
            return
        }

        let finalStart = cards.count - (5 - selection.count)
        guard start <= finalStart else { return }
        for index in start...finalStart {
            selection.append(cards[index])
            visit(index + 1)
            selection.removeLast()
        }
    }

    visit(0)
    return best!
}

private func referenceFiveKey(_ cards: [Card]) -> [Int] {
    precondition(cards.count == 5)
    let ranks = cards.map(\.rank.rawValue).sorted(by: >)
    let rankCounts = Dictionary(grouping: ranks, by: { $0 }).mapValues(\.count)
    let groups = rankCounts.map { (rank: $0.key, count: $0.value) }.sorted {
        $0.count != $1.count ? $0.count > $1.count : $0.rank > $1.rank
    }
    let flush = Set(cards.map(\.suit)).count == 1
    let uniqueRanks = Array(Set(ranks)).sorted(by: >)
    let straightHigh: Int? = if uniqueRanks == [14, 5, 4, 3, 2] {
        5
    } else if uniqueRanks.count == 5, uniqueRanks[0] - uniqueRanks[4] == 4 {
        uniqueRanks[0]
    } else {
        nil
    }

    if flush, let straightHigh { return [HandCategory.straightFlush.rawValue, straightHigh] }
    if groups[0].count == 4 {
        return [HandCategory.fourOfAKind.rawValue, groups[0].rank, groups[1].rank]
    }
    if groups[0].count == 3, groups[1].count == 2 {
        return [HandCategory.fullHouse.rawValue, groups[0].rank, groups[1].rank]
    }
    if flush { return [HandCategory.flush.rawValue] + ranks }
    if let straightHigh { return [HandCategory.straight.rawValue, straightHigh] }
    if groups[0].count == 3 {
        return [HandCategory.threeOfAKind.rawValue, groups[0].rank]
            + groups.dropFirst().map(\.rank).sorted(by: >)
    }
    if groups[0].count == 2, groups[1].count == 2 {
        let pairs = groups.prefix(2).map(\.rank).sorted(by: >)
        return [HandCategory.twoPair.rawValue] + pairs + [groups[2].rank]
    }
    if groups[0].count == 2 {
        return [HandCategory.pair.rawValue, groups[0].rank]
            + groups.dropFirst().map(\.rank).sorted(by: >)
    }
    return [HandCategory.highCard.rawValue] + ranks
}

private func lexicographicallyLess(_ lhs: [Int], _ rhs: [Int]) -> Bool {
    for (left, right) in zip(lhs, rhs) where left != right {
        return left < right
    }
    return lhs.count < rhs.count
}
