public enum Rank: Int, Codable, CaseIterable, Comparable, Sendable {
    case two = 2, three, four, five, six, seven, eight, nine, ten, jack, queen, king, ace

    public static func < (lhs: Rank, rhs: Rank) -> Bool { lhs.rawValue < rhs.rawValue }

    /// Label drawn on the card face.
    public var label: String {
        switch self {
        case .ten: return "10"
        case .jack: return "J"
        case .queen: return "Q"
        case .king: return "K"
        case .ace: return "A"
        default: return String(rawValue)
        }
    }

    /// Compact single-character form used in text descriptions.
    public var shortLabel: String {
        self == .ten ? "T" : label
    }
}
