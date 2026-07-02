/// A player action. `raise(to:)` is the new total a player has committed this
/// betting round; an opening bet is a raise from zero.
public enum PlayerAction: Codable, Sendable, Equatable {
    case fold
    case check
    case call
    case raise(to: Int)
}
