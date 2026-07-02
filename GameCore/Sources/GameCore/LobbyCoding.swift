import Foundation

private enum LobbyCodingKeys: String, CodingKey {
    case tableID, version, appliedOperationIDs, seats, maxPlayers, smallBlind, bigBlind, startingStack
}

extension Lobby {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: LobbyCodingKeys.self)
        self = Lobby(
            tableID: try container.decodeIfPresent(String.self, forKey: .tableID) ?? UUID().uuidString,
            version: try container.decodeIfPresent(Int.self, forKey: .version) ?? 0,
            appliedOperationIDs: try container.decodeIfPresent([String].self, forKey: .appliedOperationIDs) ?? [],
            maxPlayers: try container.decode(Int.self, forKey: .maxPlayers),
            smallBlind: try container.decode(Int.self, forKey: .smallBlind),
            bigBlind: try container.decode(Int.self, forKey: .bigBlind),
            startingStack: try container.decode(Int.self, forKey: .startingStack),
            seats: try container.decode([LobbySeat].self, forKey: .seats)
        )
    }
}
