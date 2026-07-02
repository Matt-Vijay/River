import Foundation

/// The lobby players see before the first hand. Identity is configured before
/// joining; the lobby only tracks seats and readiness. When all present players
/// are ready (and there are at least two), the game starts.
public struct Lobby: Codable, Sendable, Equatable {
    public static let defaultMaxPlayers = TableSize.maxPlayers
    public static let defaultSmallBlind = 5
    public static let defaultBigBlind = 10
    public static let defaultStartingStack = StartingStack.defaultAmount

    public var tableID: String
    public var version: Int
    public var appliedOperationIDs: [String]
    public var seats: [LobbySeat]
    public var maxPlayers: Int
    public var smallBlind: Int
    public var bigBlind: Int
    public var startingStack: Int

    public init(tableID: String = UUID().uuidString, version: Int = 0,
                appliedOperationIDs: [String] = [],
                maxPlayers: Int = Lobby.defaultMaxPlayers,
                smallBlind: Int = Lobby.defaultSmallBlind,
                bigBlind: Int = Lobby.defaultBigBlind,
                startingStack: Int = Lobby.defaultStartingStack,
                seats: [LobbySeat] = []) {
        let maxPlayers = TableSize.normalizedMaxPlayers(maxPlayers)
        self.tableID = TableIdentity.normalized(tableID)
        self.version = max(0, version)
        self.appliedOperationIDs = OperationIdentity.history(appliedOperationIDs)
        let blinds = BlindStructure.normalized(smallBlind: smallBlind, bigBlind: bigBlind)
        self.maxPlayers = maxPlayers
        self.smallBlind = blinds.smallBlind
        self.bigBlind = blinds.bigBlind
        self.startingStack = StartingStack.normalized(startingStack)
        self.seats = Self.normalizedSeats(seats, maxPlayers: maxPlayers)
    }

    public var isFull: Bool { seats.count >= maxPlayers }
    public var readyCount: Int { seats.filter(\.isReady).count }

    /// Game starts when there are at least two players and everyone present is ready.
    public var canStart: Bool { seats.count >= 2 && seats.allSatisfy(\.isReady) }
}

extension Lobby {
    static func normalizedSeats(_ seats: [LobbySeat], maxPlayers: Int) -> [LobbySeat] {
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
}
