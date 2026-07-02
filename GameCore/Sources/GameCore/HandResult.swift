/// The outcome for one player at the end of a hand.
public struct HandResult: Sendable, Equatable {
    public var playerID: String
    public var amountWon: Int
    public var handName: String?
    public var bestFive: [Card]?

    public init(playerID: String, amountWon: Int, handName: String?, bestFive: [Card]?) {
        self.playerID = ParticipantIdentity.normalized(playerID)
        self.amountWon = max(0, amountWon)
        self.handName = handName
        self.bestFive = Self.normalizedBestFive(bestFive)
    }
}

extension HandResult {
    static func normalizedBestFive(_ cards: [Card]?) -> [Card]? {
        guard let cards, cards.count == 5 else { return nil }
        return cards
    }
}

private enum HandResultCodingKeys: String, CodingKey {
    case playerID, amountWon, handName, bestFive
}

extension HandResult: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: HandResultCodingKeys.self)
        self.init(
            playerID: try container.decode(String.self, forKey: .playerID),
            amountWon: try container.decode(Int.self, forKey: .amountWon),
            handName: try container.decodeIfPresent(String.self, forKey: .handName),
            bestFive: try container.decodeIfPresent([Card].self, forKey: .bestFive)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: HandResultCodingKeys.self)
        try container.encode(playerID, forKey: .playerID)
        try container.encode(amountWon, forKey: .amountWon)
        try container.encodeIfPresent(handName, forKey: .handName)
        try container.encodeIfPresent(bestFive, forKey: .bestFive)
    }
}
