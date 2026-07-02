public enum PlayerStatus: String, Codable, Sendable {
    case active        // in the hand, can still act
    case folded        // out of this hand
    case allIn         // in the hand, no chips left to act with
    case sittingOut    // not dealt in
    case eliminated    // busted, no chips
}
