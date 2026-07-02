extension Array where Element == Card {
    mutating func dealTopIfAvailable() -> Card? {
        guard !isEmpty else { return nil }
        return removeFirst()
    }

    mutating func dealTopIfAvailable(_ count: Int) -> [Card] {
        let dealCount = Swift.min(Swift.max(0, count), self.count)
        let dealt = Array(prefix(dealCount))
        removeFirst(dealCount)
        return dealt
    }
}
