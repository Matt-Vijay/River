public enum ChipText {
    public static func string(_ amount: Int) -> String {
        let value = max(0, amount)
        guard value >= 1_000 else { return "\(value)" }

        let digits = Array(String(value).reversed())
        var groups: [String] = []

        for start in stride(from: 0, to: digits.count, by: 3) {
            let end = min(start + 3, digits.count)
            groups.append(String(digits[start..<end].reversed()))
        }

        return groups.reversed().joined(separator: ",")
    }
}
