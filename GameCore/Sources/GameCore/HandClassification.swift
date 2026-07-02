struct HandClassification {
    let category: HandCategory
    let tiebreakers: [Int]

    init(features: HandFeatures) {
        let groups = features.groups

        if let straightHigh = features.straightHigh, features.isFlush {
            category = .straightFlush
            tiebreakers = [straightHigh]
        } else if groups[0].count == 4 {
            category = .fourOfAKind
            tiebreakers = [groups[0].rank] + features.kickers(excluding: [groups[0].rank])
        } else if groups[0].count == 3, groups.count >= 2, groups[1].count >= 2 {
            category = .fullHouse
            tiebreakers = [groups[0].rank, groups[1].rank]
        } else if features.isFlush {
            category = .flush
            tiebreakers = features.ranksDescending
        } else if let straightHigh = features.straightHigh {
            category = .straight
            tiebreakers = [straightHigh]
        } else if groups[0].count == 3 {
            category = .threeOfAKind
            tiebreakers = [groups[0].rank] + features.kickers(excluding: [groups[0].rank])
        } else if groups[0].count == 2, groups.count >= 2, groups[1].count == 2 {
            category = .twoPair
            let hi = groups[0].rank
            let lo = groups[1].rank
            tiebreakers = [hi, lo] + features.kickers(excluding: [hi, lo])
        } else if groups[0].count == 2 {
            category = .pair
            tiebreakers = [groups[0].rank] + features.kickers(excluding: [groups[0].rank])
        } else {
            category = .highCard
            tiebreakers = features.ranksDescending
        }
    }
}
