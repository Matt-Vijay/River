enum HandCategory: Int, Comparable, Sendable {
    case highCard = 0
    case pair
    case twoPair
    case threeOfAKind
    case straight
    case flush
    case fullHouse
    case fourOfAKind
    case straightFlush

    static func < (lhs: HandCategory, rhs: HandCategory) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var name: String {
        switch self {
        case .highCard: "High Card"
        case .pair: "Pair"
        case .twoPair: "Two Pair"
        case .threeOfAKind: "Three of a Kind"
        case .straight: "Straight"
        case .flush: "Flush"
        case .fullHouse: "Full House"
        case .fourOfAKind: "Four of a Kind"
        case .straightFlush: "Straight Flush"
        }
    }
}

/// Comparable category and kickers plus the exact five cards that form a hand.
struct HandRank: Comparable, Sendable {
    let category: HandCategory
    let tiebreakers: [Int]
    let bestFive: [Card]

    var name: String {
        if category == .straightFlush, tiebreakers.first == Rank.ace.rawValue {
            return "Royal Flush"
        }
        return category.name
    }

    static func == (lhs: HandRank, rhs: HandRank) -> Bool {
        lhs.category == rhs.category && lhs.tiebreakers == rhs.tiebreakers
    }

    static func < (lhs: HandRank, rhs: HandRank) -> Bool {
        if lhs.category != rhs.category { return lhs.category < rhs.category }
        for (a, b) in zip(lhs.tiebreakers, rhs.tiebreakers) where a != b {
            return a < b
        }
        return lhs.tiebreakers.count < rhs.tiebreakers.count
    }
}

enum HandEvaluator {
    /// Best hand from 1 to 7 cards. With 6–7 cards, picks the best 5-card subset.
    static func evaluate(_ cards: [Card]) -> HandRank {
        precondition(!cards.isEmpty, "Cannot evaluate an empty hand")
        if cards.count <= 5 { return evaluateFive(cards) }

        var best: HandRank?
        var selection: [Card] = []
        selection.reserveCapacity(5)

        func visit(start: Int) {
            if selection.count == 5 {
                let rank = evaluateFive(selection)
                if best == nil || best! < rank { best = rank }
                return
            }

            let lastStart = cards.count - (5 - selection.count)
            guard start <= lastStart else { return }
            for index in start...lastStart {
                selection.append(cards[index])
                visit(start: index + 1)
                selection.removeLast()
            }
        }

        visit(start: 0)
        guard let best else {
            preconditionFailure("Cannot evaluate without a five-card combination")
        }
        return best
    }

    /// Best hand when enough card information is available.
    static func evaluateIfPossible(_ cards: [Card]) -> HandRank? {
        guard !cards.isEmpty else { return nil }
        return evaluate(cards)
    }

    /// Ranks 1-5 cards directly. Five-card categories remain unavailable until
    /// enough cards exist, which supports the live pre-river hand indicator.
    private static func evaluateFive(_ cards: [Card]) -> HandRank {
        precondition((1...5).contains(cards.count))
        let features = Features(cards: cards)
        let classification = classify(features)
        return HandRank(category: classification.category,
                        tiebreakers: classification.tiebreakers,
                        bestFive: features.bestFive)
    }

    private static func classify(_ features: Features) -> (
        category: HandCategory,
        tiebreakers: [Int]
    ) {
        let groups = features.groups

        if let straightHigh = features.straightHigh, features.isFlush {
            return (.straightFlush, [straightHigh])
        }
        if groups[0].count == 4 {
            return (.fourOfAKind,
                    [groups[0].rank] + features.kickers(excluding: groups[0].rank))
        }
        if groups[0].count == 3, groups.count >= 2, groups[1].count >= 2 {
            return (.fullHouse, [groups[0].rank, groups[1].rank])
        }
        if features.isFlush {
            return (.flush, features.ranksDescending)
        }
        if let straightHigh = features.straightHigh {
            return (.straight, [straightHigh])
        }
        if groups[0].count == 3 {
            return (.threeOfAKind,
                    [groups[0].rank] + features.kickers(excluding: groups[0].rank))
        }
        if groups[0].count == 2, groups.count >= 2, groups[1].count == 2 {
            let highPair = groups[0].rank
            let lowPair = groups[1].rank
            return (.twoPair,
                    [highPair, lowPair] + features.kickers(excluding: highPair, and: lowPair))
        }
        if groups[0].count == 2 {
            return (.pair,
                    [groups[0].rank] + features.kickers(excluding: groups[0].rank))
        }
        return (.highCard, features.ranksDescending)
    }

    private struct Features {
        let ranksDescending: [Int]
        let groups: [(rank: Int, count: Int)]
        let isFlush: Bool
        let straightHigh: Int?
        let bestFive: [Card]

        init(cards: [Card]) {
            ranksDescending = cards.map { $0.rank.rawValue }.sorted(by: >)
            var groups: [(rank: Int, count: Int)] = []
            for rank in ranksDescending {
                if let last = groups.indices.last, groups[last].rank == rank {
                    groups[last].count += 1
                } else {
                    groups.append((rank, 1))
                }
            }
            self.groups = groups.sorted {
                $0.count != $1.count ? $0.count > $1.count : $0.rank > $1.rank
            }
            isFlush = cards.count == 5 && cards.dropFirst().allSatisfy { $0.suit == cards[0].suit }
            straightHigh = HandEvaluator.straightHigh(in: ranksDescending)
            bestFive = cards.sorted(by: >)
        }

        func kickers(excluding first: Int, and second: Int? = nil) -> [Int] {
            if let second {
                return ranksDescending.filter { $0 != first && $0 != second }
            }
            return ranksDescending.filter { $0 != first }
        }
    }

    private static func straightHigh(in ranksDescending: [Int]) -> Int? {
        guard ranksDescending.count == 5 else { return nil }
        if ranksDescending[0] - ranksDescending[4] == 4,
           zip(ranksDescending, ranksDescending.dropFirst()).allSatisfy({ $0 == $1 + 1 }) {
            return ranksDescending[0]
        }
        if ranksDescending == [14, 5, 4, 3, 2] { return 5 }
        return nil
    }
}
