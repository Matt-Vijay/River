struct HandFeatures {
    let ranksDescending: [Int]
    let groups: [RankGroup]
    let isFlush: Bool
    let straightHigh: Int?
    let bestFive: [Card]

    init(cards: [Card]) {
        ranksDescending = cards.map { $0.rank.rawValue }.sorted(by: >)
        groups = RankGroup.groups(from: ranksDescending)
        isFlush = cards.count == 5 && Set(cards.map(\.suit)).count == 1
        straightHigh = StraightDetector.highCard(in: ranksDescending)
        bestFive = cards.sorted(by: >)
    }

    func kickers(excluding excluded: Set<Int>) -> [Int] {
        ranksDescending.filter { !excluded.contains($0) }
    }
}
