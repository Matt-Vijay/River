extension Sequence where Element: Hashable {
    func orderedUnique() -> [Element] {
        var seen: Set<Element> = []
        var unique: [Element] = []
        for element in self where seen.insert(element).inserted {
            unique.append(element)
        }
        return unique
    }
}
