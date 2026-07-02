extension Card {
    // Compact Codable: a card is just its integer code.
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(Int.self)
        guard let card = Card(code: value) else {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Invalid card code \(value)")
        }
        self = card
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(code)
    }
}
