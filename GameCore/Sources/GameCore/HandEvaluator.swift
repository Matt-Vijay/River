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
        return lhs.tiebreakers.lexicographicallyPrecedes(rhs.tiebreakers)
    }
}

enum HandEvaluator {
    /// Best hand from 1 to 7 cards. With 6–7 cards, picks the best 5-card subset.
    static func evaluate(_ cards: [Card]) -> HandRank {
        precondition((1...7).contains(cards.count), "Hold'em hands contain 1...7 cards")
        precondition(Set(cards).count == cards.count, "Cannot evaluate duplicate cards")
        if cards.count <= 5 { return evaluateFive(cards) }

        var best: HandRank?
        var selection: [Card] = []
        selection.reserveCapacity(5)

        func visit(start: Int) {
            if selection.count == 5 {
                let rank = evaluateFive(selection)
                if best == nil || rank.isPreferredRepresentation(over: best!) {
                    best = rank
                }
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
        let ranks = cards.map(\.rank.rawValue).sorted(by: >)
        let groups = Dictionary(grouping: ranks, by: { $0 })
            .map { (rank: $0.key, count: $0.value.count) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.rank > $1.rank }
        let isFlush = cards.count == 5 && cards.allSatisfy { $0.suit == cards[0].suit }
        let straightHigh: Int? = if ranks == [14, 5, 4, 3, 2] {
            5
        } else if groups.count == 5, ranks[0] - ranks[4] == 4 {
            ranks[0]
        } else {
            nil
        }

        // Multiplicity, then rank, is the tie order for every grouped hand.
        // Flush/high-card ranks are already unique; only straights collapse to one high card.
        var tiebreakers = groups.map(\.rank)
        let category: HandCategory
        if let straightHigh, isFlush {
            category = .straightFlush
            tiebreakers = [straightHigh]
        } else if groups[0].count == 4 {
            category = .fourOfAKind
        } else if groups[0].count == 3, groups.count == 2, groups[1].count == 2 {
            category = .fullHouse
        } else if isFlush {
            category = .flush
        } else if let straightHigh {
            category = .straight
            tiebreakers = [straightHigh]
        } else if groups[0].count == 3 {
            category = .threeOfAKind
        } else if groups[0].count == 2, groups.count >= 2, groups[1].count == 2 {
            category = .twoPair
        } else if groups[0].count == 2 {
            category = .pair
        } else {
            category = .highCard
        }
        return HandRank(category: category, tiebreakers: tiebreakers, bestFive: cards.sorted(by: >))
    }
}

private extension HandRank {
    /// Suits never break a poker tie, but several five-card subsets can represent
    /// the same rank. Pick one canonical subset so replaying the same cards in a
    /// different order still produces identical result metadata.
    func isPreferredRepresentation(over other: HandRank) -> Bool {
        if self != other { return self > other }
        return other.bestFive.lexicographicallyPrecedes(bestFive)
    }
}
