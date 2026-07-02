/// One seat in the pre-game lobby.
public struct LobbySeat: Sendable, Identifiable, Equatable {
    public var id: String
    public var name: String
    public var avatar: String
    public var isReady: Bool

    public init(id: String, name: String, avatar: String, isReady: Bool = false) {
        self.id = ParticipantIdentity.normalized(id)
        self.name = ProfileText.name(name)
        self.avatar = ProfileText.avatar(avatar)
        self.isReady = isReady
    }

    mutating func updateProfile(name: String? = nil, avatar: String? = nil,
                                isReady: Bool? = nil) {
        if let name { self.name = ProfileText.name(name) }
        if let avatar { self.avatar = ProfileText.avatar(avatar) }
        if let isReady { self.isReady = isReady }
    }
}

private enum LobbySeatCodingKeys: String, CodingKey {
    case id, name, avatar, isReady
}

extension LobbySeat: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: LobbySeatCodingKeys.self)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            name: try container.decode(String.self, forKey: .name),
            avatar: try container.decode(String.self, forKey: .avatar),
            isReady: try container.decode(Bool.self, forKey: .isReady)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: LobbySeatCodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(avatar, forKey: .avatar)
        try container.encode(isReady, forKey: .isReady)
    }
}
