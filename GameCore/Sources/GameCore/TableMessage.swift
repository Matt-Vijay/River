import Foundation

public enum TableOperation: Sendable, Equatable {
    case joinLobby(name: String, avatar: String)
    case startGame(seed: UInt64, turnDuration: TimeInterval)
    case leaveLobby
    case gameAction(PlayerAction)
    case resolveTimeout
    case joinGame(name: String, avatar: String, startingStack: Int)
    case leaveGame
    case dealNextHand(seed: UInt64)

}

public enum TableOperationRejection: Sendable, Equatable {
    case stale
    case wrongPhase
    case notSeated
    case notActorTurn
    case illegalAction
    case tableFull
    case gameOver
}

public enum TableOperationResult: Sendable, Equatable {
    case applied(TableMessage)
    case unchanged
    case rejected(TableOperationRejection)
}

enum Identity {
    static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalized(_ value: String) -> String {
        let trimmed = trimmed(value)
        return trimmed.isEmpty ? UUID().uuidString : trimmed
    }

    static func decoded(_ value: String, error: String,
                        codingPath: [CodingKey]) throws -> String {
        let trimmed = trimmed(value)
        guard !trimmed.isEmpty else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: codingPath, debugDescription: error))
        }
        return trimmed
    }

    static func requireUnique(_ ids: [String], codingPath: [CodingKey]) throws {
        guard Set(ids).count == ids.count else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: codingPath,
                      debugDescription: "Participant identities must be unique")
            )
        }
    }

    static func uniquePlayers(_ players: [Player]) -> [Player] {
        var seen: Set<String> = []
        return players.map { player in
            var copy = player
            var candidate = normalized(copy.id)
            while !seen.insert(candidate).inserted {
                candidate = UUID().uuidString
            }
            copy.id = candidate
            return copy
        }
    }
}

enum MonotonicCounter {
    static func successor(of value: Int) -> Int? {
        let result = value.addingReportingOverflow(1)
        return result.overflow ? nil : result.partialValue
    }
}

public struct TableRevision: Codable, Sendable, Equatable {
    private enum CodingKeys: String, CodingKey { case tableID, phase, version, branch }

    enum Phase: Int, Codable, Sendable {
        case lobby = 0
        case game = 1
    }

    public let tableID: String
    let phase: Phase
    let version: Int
    /// Stable state digest used only to order concurrent equal-version messages.
    private let branch: String

    init(tableID: String, phase: Phase, version: Int, branch: String = "") {
        self.tableID = Identity.normalized(tableID)
        self.phase = phase
        self.version = max(0, version)
        self.branch = branch
    }

    public func isOlder(than other: TableRevision) -> Bool {
        guard tableID == other.tableID else { return false }
        if phase != other.phase { return phase.rawValue < other.phase.rawValue }
        if version != other.version { return version < other.version }
        return branch < other.branch
    }

    public func isSameOrNewer(than other: TableRevision) -> Bool {
        tableID == other.tableID && !isOlder(than: other)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tableID = try Identity.decoded(
            container.decode(String.self, forKey: .tableID),
            error: "Blank table identity",
            codingPath: container.codingPath + [CodingKeys.tableID])
        phase = try container.decode(Phase.self, forKey: .phase)
        version = max(0, try container.decode(Int.self, forKey: .version))
        branch = try container.decodeIfPresent(String.self, forKey: .branch) ?? ""
    }
}

/// What a conversation's message carries: either the lobby (pre-game) or a live
/// game state. The whole thing travels in the `MSMessage.url`.
public enum TableMessage: Sendable, Equatable {
    case lobby(Lobby)
    case game(GameState)
}

extension TableMessage: Codable {
    private static let currentWireVersion = 1

    private enum CodingKeys: String, CodingKey { case wireVersion, lobby, game }

    private enum PayloadCodingKeys: String, CodingKey { case value = "_0" }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let wireVersion = try container.decodeIfPresent(Int.self, forKey: .wireVersion) ?? 0
        guard wireVersion == 0 || wireVersion == Self.currentWireVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .wireVersion, in: container,
                debugDescription: "Unsupported table message wire version")
        }

        switch (container.contains(.lobby), container.contains(.game)) {
        case (true, false):
            let payload = try container.nestedContainer(
                keyedBy: PayloadCodingKeys.self, forKey: .lobby)
            self = .lobby(try payload.decode(Lobby.self, forKey: .value))
        case (false, true):
            let payload = try container.nestedContainer(
                keyedBy: PayloadCodingKeys.self, forKey: .game)
            self = .game(try payload.decode(GameState.self, forKey: .value))
        default:
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: container.codingPath,
                    debugDescription: "Expected exactly one table message payload"))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.currentWireVersion, forKey: .wireVersion)

        switch self {
        case .lobby(let lobby):
            var payload = container.nestedContainer(keyedBy: PayloadCodingKeys.self, forKey: .lobby)
            try payload.encode(lobby, forKey: .value)
        case .game(let state):
            var payload = container.nestedContainer(keyedBy: PayloadCodingKeys.self, forKey: .game)
            try payload.encode(state, forKey: .value)
        }
    }
}

extension TableMessage {
    public var revision: TableRevision {
        switch self {
        case .lobby(let lobby):
            return TableRevision(
                tableID: lobby.tableID, phase: .lobby, version: lobby.version,
                branch: GamePayload.conflictKey(for: self))
        case .game(let state):
            return TableRevision(
                tableID: state.tableID, phase: .game, version: state.version,
                branch: GamePayload.conflictKey(for: self))
        }
    }

    public func committing(
        _ kind: TableOperation, actorID: String,
        latestRevision: TableRevision? = nil, now: Date = Date()
    ) -> TableOperationResult {
        if let latestRevision, revision.isOlder(than: latestRevision) {
            return .rejected(.stale)
        }
        let actorID = Identity.trimmed(actorID)
        guard !actorID.isEmpty else { return .rejected(.notSeated) }

        return switch self {
        case .lobby(let lobby): lobby.applying(kind, actorID: actorID, now: now)
        case .game(let state): state.applying(kind, actorID: actorID, now: now)
        }
    }
}
