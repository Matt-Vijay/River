public enum Street: Int, Codable, Sendable, CaseIterable {
    case preflop, flop, turn, river, showdown

    /// Total community cards visible by this street.
    public var boardCount: Int {
        switch self {
        case .preflop: return 0
        case .flop: return 3
        case .turn: return 4
        case .river, .showdown: return 5
        }
    }
}
