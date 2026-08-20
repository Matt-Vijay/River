public enum PlayerStatus: String, Codable, Sendable {
    case active
    case folded
    case allIn
    case sittingOut
    case eliminated
}

public struct Player: Sendable, Identifiable, Equatable {
    public internal(set) var id: String
    public internal(set) var name: String
    public internal(set) var avatar: String
    public internal(set) var stack: Int
    /// Chips committed in the current betting round.
    public internal(set) var bet: Int
    /// Total chips committed across the whole hand (drives side pots).
    var committed: Int
    public internal(set) var status: PlayerStatus
    public internal(set) var holeCards: [Card]
    /// The player's bet immediately after their most recent action this street.
    /// A later increase of at least `minRaise` reopens raising without mutating
    /// every other player.
    var lastActionBet: Int?
    public internal(set) var lastAction: PlayerAction?
    /// True once the player has left the table (excluded from future hands until
    /// they rejoin). They can come back at any time.
    public internal(set) var hasLeft: Bool

    init(id: String, name: String, avatar: String, stack: Int) {
        self.id = Identity.normalized(id)
        self.name = ProfileText.name(name)
        self.avatar = ProfileText.avatar(avatar)
        self.stack = TableRules.table(stack)
        self.bet = 0
        self.committed = 0
        self.status = .active
        self.holeCards = []
        self.lastActionBet = nil
        self.lastAction = nil
        self.hasLeft = false
    }

    public var isContesting: Bool { status == .active || status == .allIn }
    var canAct: Bool { status == .active }
    var isEligibleForNextHand: Bool { !hasLeft && stack > 0 }
}

private enum PlayerCodingKeys: String, CodingKey {
    case id, name, avatar, stack, bet, committed, status, holeCards
    case lastActionBet, hasActed, lastAction, hasLeft
}

extension Player: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: PlayerCodingKeys.self)
        id = try Identity.decoded(
            container.decode(String.self, forKey: .id),
            error: "Participant identity cannot be blank",
            codingPath: container.codingPath + [PlayerCodingKeys.id]
        )
        name = try ProfileText.decodedName(
            container.decode(String.self, forKey: .name),
            codingPath: container.codingPath + [PlayerCodingKeys.name]
        )
        avatar = try ProfileText.decodedAvatar(
            container.decode(String.self, forKey: .avatar),
            codingPath: container.codingPath + [PlayerCodingKeys.avatar]
        )
        stack = TableRules.table(try container.decode(Int.self, forKey: .stack))
        bet = TableRules.table(try container.decode(Int.self, forKey: .bet))
        committed = max(
            TableRules.table(try container.decode(Int.self, forKey: .committed)),
            bet
        )
        status = try container.decode(PlayerStatus.self, forKey: .status)
        holeCards = try container.decode([Card].self, forKey: .holeCards)
        guard holeCards.count <= 2 else {
            throw DecodingError.dataCorruptedError(
                forKey: .holeCards, in: container,
                debugDescription: "A player cannot hold more than two cards")
        }
        let legacyHasActed = try container.decodeIfPresent(Bool.self, forKey: .hasActed)
        if container.contains(.lastActionBet) {
            lastActionBet = try container.decodeIfPresent(Int.self, forKey: .lastActionBet)
            if let legacyHasActed, legacyHasActed != (lastActionBet != nil) {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: container.codingPath,
                    debugDescription: "Conflicting player action markers"
                ))
            }
        } else if let legacyHasActed {
            lastActionBet = legacyHasActed ? bet : nil
        } else {
            throw DecodingError.keyNotFound(
                PlayerCodingKeys.hasActed,
                .init(
                    codingPath: container.codingPath,
                    debugDescription: "Player action marker is required"
                )
            )
        }
        lastAction = try container.decodeIfPresent(PlayerAction.self, forKey: .lastAction)
        hasLeft = try container.decode(Bool.self, forKey: .hasLeft)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: PlayerCodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(avatar, forKey: .avatar)
        try container.encode(stack, forKey: .stack)
        try container.encode(bet, forKey: .bet)
        try container.encode(committed, forKey: .committed)
        try container.encode(status, forKey: .status)
        try container.encode(holeCards, forKey: .holeCards)
        try container.encodeIfPresent(lastActionBet, forKey: .lastActionBet)
        try container.encode(lastActionBet != nil, forKey: .hasActed)
        try container.encodeIfPresent(lastAction, forKey: .lastAction)
        try container.encode(hasLeft, forKey: .hasLeft)
    }
}
