enum SummaryNameText {
    private static let maxLength = 18

    static func string(_ name: String) -> String {
        let normalized = ProfileText.name(name)
        guard normalized.count > maxLength else { return normalized }
        return String(normalized.prefix(maxLength - 1)) + "…"
    }
}
