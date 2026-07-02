public enum Suit: Int, Codable, CaseIterable, Sendable {
    case clubs = 0, diamonds, hearts, spades

    public var isRed: Bool { self == .diamonds || self == .hearts }

    /// Glyph used on the card face in the UI.
    public var symbol: String {
        switch self {
        case .clubs: return "\u{2663}"
        case .diamonds: return "\u{2666}"
        case .hearts: return "\u{2665}"
        case .spades: return "\u{2660}"
        }
    }

    /// Single-letter code used in compact text descriptions.
    public var letter: String {
        switch self {
        case .clubs: return "c"
        case .diamonds: return "d"
        case .hearts: return "h"
        case .spades: return "s"
        }
    }
}
