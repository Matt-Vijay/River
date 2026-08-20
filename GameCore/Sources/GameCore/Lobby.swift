import Foundation

/// One seat in the pre-game lobby.
public struct LobbySeat: Codable, Sendable, Identifiable, Equatable {
    private enum CodingKeys: String, CodingKey { case id, name, avatar }

    public internal(set) var id: String
    public internal(set) var name: String
    public internal(set) var avatar: String

    init(id: String, name: String, avatar: String) {
        self.id = Identity.normalized(id)
        self.name = ProfileText.name(name)
        self.avatar = ProfileText.avatar(avatar)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try Identity.decoded(
            container.decode(String.self, forKey: .id),
            error: "Participant identity cannot be blank",
            codingPath: container.codingPath + [CodingKeys.id])
        name = try ProfileText.decodedName(
            container.decode(String.self, forKey: .name),
            codingPath: container.codingPath + [CodingKeys.name])
        avatar = try ProfileText.decodedAvatar(
            container.decode(String.self, forKey: .avatar),
            codingPath: container.codingPath + [CodingKeys.avatar])
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(avatar, forKey: .avatar)
    }
}

/// The lobby players see before the first hand. It tracks only table seats;
/// starting is an explicit action once at least two players are present.
public struct Lobby: Codable, Sendable, Equatable {
    private enum CodingKeys: String, CodingKey {
        case tableID, version, seats, maxPlayers
        case smallBlind, bigBlind, startingStack
    }

    public static let defaultMaxPlayers = TableRules.maxPlayers
    public static let defaultSmallBlind = 5
    public static let defaultBigBlind = 10
    public static let defaultStartingStack = TableRules.defaultStartingStack

    public internal(set) var tableID: String
    var version: Int
    public internal(set) var seats: [LobbySeat]
    public internal(set) var maxPlayers: Int
    var smallBlind: Int
    var bigBlind: Int
    var startingStack: Int

    public init(
        tableID: String = UUID().uuidString, version: Int = 0,
        maxPlayers: Int = Lobby.defaultMaxPlayers, smallBlind: Int = Lobby.defaultSmallBlind,
        bigBlind: Int = Lobby.defaultBigBlind, startingStack: Int = Lobby.defaultStartingStack,
        seats: [LobbySeat] = []
    ) {
        let maxPlayers = TableRules.normalizedMaxPlayers(maxPlayers)
        self.tableID = Identity.normalized(tableID)
        self.version = max(0, version)
        let blinds = TableRules.normalizedBlinds(smallBlind: smallBlind, bigBlind: bigBlind)
        self.maxPlayers = maxPlayers
        self.smallBlind = blinds.smallBlind
        self.bigBlind = blinds.bigBlind
        self.startingStack = TableRules.normalizedStartingStack(startingStack)
        self.seats = Self.normalizedSeats(seats, maxPlayers: maxPlayers)
    }

    public var isFull: Bool { seats.count >= maxPlayers }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let tableID =
            try container.decodeIfPresent(String.self, forKey: .tableID).map {
                try Identity.decoded(
                    $0, error: "Blank table identity",
                    codingPath: container.codingPath + [CodingKeys.tableID])
            } ?? GamePayload.legacyTableID(from: decoder)
        let seats = try container.decode([LobbySeat].self, forKey: .seats)
        try Identity.requireUnique(
            seats.map(\.id), codingPath: container.codingPath + [CodingKeys.seats])
        let maxPlayers = try container.decode(Int.self, forKey: .maxPlayers)
        guard (TableRules.minPlayers...TableRules.maxPlayers).contains(maxPlayers),
              seats.count <= maxPlayers else {
            throw DecodingError.dataCorruptedError(
                forKey: .seats, in: container,
                debugDescription: "Lobby player limits are invalid")
        }
        self.init(
            tableID: tableID,
            version: try container.decodeIfPresent(Int.self, forKey: .version) ?? 0,
            maxPlayers: maxPlayers,
            smallBlind: try container.decode(Int.self, forKey: .smallBlind),
            bigBlind: try container.decode(Int.self, forKey: .bigBlind),
            startingStack: try container.decode(Int.self, forKey: .startingStack), seats: seats)
    }
}

extension Lobby {
    private static func normalizedSeats(_ seats: [LobbySeat], maxPlayers: Int) -> [LobbySeat] {
        var normalized: [LobbySeat] = []
        for seat in seats {
            if let index = normalized.firstIndex(where: { $0.id == seat.id }) {
                normalized[index] = seat
            } else if normalized.count < maxPlayers {
                normalized.append(seat)
            }
        }
        return normalized
    }

    public func seat(id: String) -> LobbySeat? { seats.first { $0.id == id } }

    private func game(seed: UInt64, turnDuration: TimeInterval, now: Date) -> GameState {
        let players = seats.map {
            Player(id: $0.id, name: $0.name, avatar: $0.avatar, stack: startingStack)
        }
        return GameState.startHand(
            players: players, dealerIndex: 0, smallBlind: smallBlind, bigBlind: bigBlind,
            seed: seed, handNumber: 1, tableID: tableID,
            turnDuration: turnDuration, now: now)
    }

    private func revised(with seats: [LobbySeat]) -> Lobby? {
        guard let version = MonotonicCounter.successor(of: version) else { return nil }
        var next = self
        next.seats = seats
        next.version = version
        return next
    }

    func applying(_ kind: TableOperation, actorID: String, now: Date) -> TableOperationResult {
        switch kind {
        case .joinLobby(let name, let avatar):
            return joiningLobby(actorID: actorID, name: name, avatar: avatar)
        case .startGame(let seed, let duration):
            guard seat(id: actorID) != nil else { return .rejected(.notSeated) }
            guard seats.count >= 2 else { return .rejected(.illegalAction) }
            guard MonotonicCounter.successor(of: version) != nil else {
                return .rejected(.illegalAction)
            }
            return .applied(.game(game(seed: seed, turnDuration: duration, now: now)))
        case .leaveLobby:
            return leavingLobby(actorID: actorID)
        default: return .rejected(.wrongPhase)
        }
    }

    private func joiningLobby(actorID: String, name: String, avatar: String) -> TableOperationResult
    {
        guard seat(id: actorID) == nil else { return .unchanged }
        guard !isFull else { return .rejected(.tableFull) }
        let seats = seats + [LobbySeat(id: actorID, name: name, avatar: avatar)]
        guard let next = revised(with: seats) else { return .rejected(.illegalAction) }
        return .applied(.lobby(next))
    }

    private func leavingLobby(actorID: String) -> TableOperationResult {
        guard let index = seats.firstIndex(where: { $0.id == actorID }) else {
            return .rejected(.notSeated)
        }
        var seats = seats
        seats.remove(at: index)
        guard let next = revised(with: seats) else {
            return .rejected(.illegalAction)
        }
        return .applied(.lobby(next))
    }
}
