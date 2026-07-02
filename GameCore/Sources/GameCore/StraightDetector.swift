enum StraightDetector {
    static func highCard(in ranksDescending: [Int]) -> Int? {
        let distinct = Set(ranksDescending)
        guard distinct.count == 5 else { return nil }

        let ranks = distinct.sorted(by: >)
        if ranks[0] - ranks[4] == 4 { return ranks[0] }
        if distinct == [14, 5, 4, 3, 2] { return 5 }
        return nil
    }
}
