public struct Player: Sendable, Identifiable, Equatable {
    public var id: String
    public var name: String
    public var avatar: String
    public var stack: Int
    /// Chips committed in the current betting round.
    public var bet: Int
    /// Total chips committed across the whole hand (drives side pots).
    public var committed: Int
    public var status: PlayerStatus
    public var holeCards: [Card]
    /// Whether the player has acted since the current bet level was set.
    public var hasActed: Bool
    public var lastAction: PlayerAction?
    /// True once the player has left the table (excluded from future hands until
    /// they rejoin). They can come back at any time.
    public var hasLeft: Bool

    public init(id: String, name: String, avatar: String, stack: Int) {
        self.id = ParticipantIdentity.normalized(id)
        self.name = ProfileText.name(name)
        self.avatar = ProfileText.avatar(avatar)
        self.stack = max(0, stack)
        self.bet = 0
        self.committed = 0
        self.status = .active
        self.holeCards = []
        self.hasActed = false
        self.lastAction = nil
        self.hasLeft = false
    }

    public var isContesting: Bool { status == .active || status == .allIn }
    public var canAct: Bool { status == .active }
    var canEnterNextHand: Bool { !hasLeft && stack > 0 }
}

private enum PlayerCodingKeys: String, CodingKey {
    case id, name, avatar, stack, bet, committed, status, holeCards, hasActed, lastAction, hasLeft
}

extension Player: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: PlayerCodingKeys.self)
        id = ParticipantIdentity.normalized(try container.decode(String.self, forKey: .id))
        name = ProfileText.name(try container.decode(String.self, forKey: .name))
        avatar = ProfileText.avatar(try container.decode(String.self, forKey: .avatar))
        stack = max(0, try container.decode(Int.self, forKey: .stack))
        bet = max(0, try container.decode(Int.self, forKey: .bet))
        committed = max(0, try container.decode(Int.self, forKey: .committed))
        status = try container.decode(PlayerStatus.self, forKey: .status)
        holeCards = Array(try container.decode([Card].self, forKey: .holeCards).prefix(2))
        hasActed = try container.decode(Bool.self, forKey: .hasActed)
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
        try container.encode(hasActed, forKey: .hasActed)
        try container.encodeIfPresent(lastAction, forKey: .lastAction)
        try container.encode(hasLeft, forKey: .hasLeft)
    }
}
