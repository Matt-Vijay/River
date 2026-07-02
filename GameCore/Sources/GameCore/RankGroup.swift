struct RankGroup {
    let rank: Int
    let count: Int

    static func groups(from ranksDescending: [Int]) -> [RankGroup] {
        var frequency: [Int: Int] = [:]
        for rank in ranksDescending {
            frequency[rank, default: 0] += 1
        }

        return frequency
            .map { RankGroup(rank: $0.key, count: $0.value) }
            .sorted { lhs, rhs in
                lhs.count != rhs.count ? lhs.count > rhs.count : lhs.rank > rhs.rank
            }
    }
}
