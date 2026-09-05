import Foundation

public enum TableOperation: Codable, Sendable, Equatable {
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
    static let maximumUTF8Length = 128

    static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalized(_ value: String) -> String {
        let trimmed = trimmed(value)
        return isValid(trimmed) ? trimmed : UUID().uuidString
    }

    static func decoded(_ value: String, error: String,
                        codingPath: [CodingKey]) throws -> String {
        let trimmed = trimmed(value)
        guard isValid(trimmed) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: codingPath, debugDescription: error))
        }
        return trimmed
    }

    static func actor(_ value: String) -> String? {
        let trimmed = trimmed(value)
        return isValid(trimmed) ? trimmed : nil
    }

    private static func isValid(_ value: String) -> Bool {
        !value.isEmpty
            && value.utf8.count <= maximumUTF8Length
            && value.unicodeScalars.allSatisfy {
                !CharacterSet.controlCharacters.contains($0)
            }
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
            let base = normalized(copy.id)
            var candidate = base
            var suffix = 1
            while !seen.insert(candidate).inserted {
                candidate = "\(base)-\(suffix)"
                suffix += 1
            }
            copy.id = candidate
            return copy
        }
    }
}

/// A locally authenticated Messages participant mapped to a stable table seat.
/// The wire state never grants authority by itself: callers must construct this
/// value from their local conversation identity before committing an operation.
public struct TableActor: Sendable, Equatable, Hashable {
    public let id: String

    public init?(_ id: String) {
        guard let id = Identity.actor(id) else { return nil }
        self.id = id
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

    public enum Phase: Int, Codable, Sendable {
        case lobby = 0
        case game = 1
    }

    public let tableID: String
    public let phase: Phase
    public let version: Int
    /// Stable state digest used only to order concurrent equal-version messages.
    let branch: String

    init(tableID: String, phase: Phase, version: Int, branch: String = "") {
        self.tableID = Identity.normalized(tableID)
        self.phase = phase
        self.version = max(0, version)
        self.branch = branch
    }

    public func isOlder(than other: TableRevision) -> Bool {
        switch disposition(comparedTo: other) {
        case .stale, .conflicting(preferred: false): true
        default: false
        }
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
        version = try container.decode(Int.self, forKey: .version)
        guard version >= 0 else {
            throw DecodingError.dataCorruptedError(
                forKey: .version, in: container,
                debugDescription: "Table revision cannot be negative")
        }
        let branch = try container.decodeIfPresent(String.self, forKey: .branch) ?? ""
        guard branch.isEmpty || (branch.utf8.count == 32 && branch.utf8.allSatisfy({ byte in
            (48...57).contains(byte) || (97...102).contains(byte)
        })) else {
            throw DecodingError.dataCorruptedError(
                forKey: .branch, in: container,
                debugDescription: "Table revision fingerprint is invalid")
        }
        self.branch = branch
    }
}

public enum TableRevisionDisposition: Sendable, Equatable {
    case firstSeen
    case differentTable
    case duplicate
    case newer
    case stale
    /// Equal phase/version states created concurrently. `preferred` is a stable
    /// digest tie-break, not proof that either sender was trustworthy.
    case conflicting(preferred: Bool)
}

public extension TableRevision {
    func disposition(comparedTo latest: TableRevision?) -> TableRevisionDisposition {
        guard let latest else { return .firstSeen }
        guard tableID == latest.tableID else { return .differentTable }
        if phase != latest.phase {
            return phase.rawValue > latest.phase.rawValue ? .newer : .stale
        }
        if version != latest.version { return version > latest.version ? .newer : .stale }
        if branch == latest.branch { return .duplicate }

        // A missing branch comes from the pre-fingerprint revision-store format.
        // Prefer a known fingerprint without surfacing a false conflict during
        // migration.
        if latest.branch.isEmpty { return .newer }
        if branch.isEmpty { return .stale }
        return .conflicting(preferred: branch > latest.branch)
    }

    func conflicts(with other: TableRevision) -> Bool {
        guard tableID == other.tableID,
              phase == other.phase,
              version == other.version,
              !branch.isEmpty,
              !other.branch.isEmpty else { return false }
        return branch != other.branch
    }
}

/// What a conversation's message carries: either the lobby (pre-game) or a live
/// game state. The whole thing travels in the `MSMessage.url`.
public enum TableMessage: Sendable, Equatable {
    case lobby(Lobby)
    case game(GameState)
}

extension TableMessage: Codable {
    private static let currentWireVersion = 2

    private enum CodingKeys: String, CodingKey { case wireVersion, integrity, lobby, game }

    private enum PayloadCodingKeys: String, CodingKey { case value = "_0" }

    private struct AnyCodingKey: CodingKey {
        let stringValue: String
        let intValue: Int? = nil

        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
    }

    public init(from decoder: Decoder) throws {
        let shape = try decoder.container(keyedBy: AnyCodingKey.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let wireVersion = try container.decodeIfPresent(Int.self, forKey: .wireVersion) ?? 0
        guard (0...Self.currentWireVersion).contains(wireVersion) else {
            throw DecodingError.dataCorruptedError(
                forKey: .wireVersion, in: container,
                debugDescription: "Unsupported table message wire version")
        }
        let allowedKeys: Set<String> = wireVersion == Self.currentWireVersion
            ? [CodingKeys.wireVersion.rawValue, CodingKeys.integrity.rawValue,
               CodingKeys.lobby.rawValue, CodingKeys.game.rawValue]
            : [CodingKeys.wireVersion.rawValue, CodingKeys.lobby.rawValue,
               CodingKeys.game.rawValue]
        guard Set(shape.allKeys.map(\.stringValue)).isSubset(of: allowedKeys) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: container.codingPath,
                      debugDescription: "Unknown table message fields"))
        }

        let decoded: TableMessage
        switch (container.contains(.lobby), container.contains(.game)) {
        case (true, false):
            try Self.validatePayloadShape(for: .lobby, in: container)
            let payload = try container.nestedContainer(
                keyedBy: PayloadCodingKeys.self, forKey: .lobby)
            decoded = .lobby(try payload.decode(Lobby.self, forKey: .value))
        case (false, true):
            try Self.validatePayloadShape(for: .game, in: container)
            let payload = try container.nestedContainer(
                keyedBy: PayloadCodingKeys.self, forKey: .game)
            decoded = .game(try payload.decode(GameState.self, forKey: .value))
        default:
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: container.codingPath,
                    debugDescription: "Expected exactly one table message payload"))
        }

        if wireVersion == Self.currentWireVersion {
            let integrity = try container.decode(String.self, forKey: .integrity)
            guard integrity.utf8.count == 64,
                  integrity.utf8.allSatisfy({ byte in
                      (48...57).contains(byte) || (97...102).contains(byte)
                  }) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .integrity, in: container,
                    debugDescription: "Table message integrity metadata is invalid")
            }
            if decoder.userInfo[GamePayload.integrityPrevalidatedKey] as? Bool != true,
               !GamePayload.integrityMatches(integrity, message: decoded) {
                throw DecodingError.dataCorruptedError(
                    forKey: .integrity, in: container,
                    debugDescription: "Table message integrity check failed")
            }
        } else if container.contains(.integrity) {
            throw DecodingError.dataCorruptedError(
                forKey: .integrity, in: container,
                debugDescription: "Legacy table messages cannot claim current integrity")
        }
        self = decoded
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.currentWireVersion, forKey: .wireVersion)
        try container.encode(GamePayload.integrityDigest(for: self), forKey: .integrity)

        switch self {
        case .lobby(let lobby):
            var payload = container.nestedContainer(keyedBy: PayloadCodingKeys.self, forKey: .lobby)
            try payload.encode(lobby, forKey: .value)
        case .game(let state):
            var payload = container.nestedContainer(keyedBy: PayloadCodingKeys.self, forKey: .game)
            try payload.encode(state, forKey: .value)
        }
    }

    private static func validatePayloadShape(
        for key: CodingKeys, in container: KeyedDecodingContainer<CodingKeys>
    ) throws {
        let decoder = try container.superDecoder(forKey: key)
        let payload = try decoder.container(keyedBy: AnyCodingKey.self)
        guard payload.allKeys.map(\.stringValue) == [PayloadCodingKeys.value.rawValue] else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: payload.codingPath,
                      debugDescription: "Invalid table payload wrapper"))
        }
    }
}

extension TableMessage {
    public var revision: TableRevision {
        switch self {
        case .lobby(let lobby):
            return TableRevision(
                tableID: lobby.tableID, phase: .lobby, version: lobby.version,
                branch: GamePayload.stateFingerprint(for: self))
        case .game(let state):
            return TableRevision(
                tableID: state.tableID, phase: .game, version: state.version,
                branch: GamePayload.stateFingerprint(for: self))
        }
    }

    public func committing(
        _ kind: TableOperation, actorID: String,
        latestRevision: TableRevision? = nil, now: Date = Date()
    ) -> TableOperationResult {
        guard let actor = TableActor(actorID) else { return .rejected(.notSeated) }
        return committing(kind, actor: actor, latestRevision: latestRevision, now: now)
    }

    public func committing(
        _ kind: TableOperation, actor: TableActor,
        latestRevision: TableRevision? = nil, now: Date = Date()
    ) -> TableOperationResult {
        let revision = revision
        switch revision.disposition(comparedTo: latestRevision) {
        case .differentTable, .stale, .conflicting(preferred: false):
            return .rejected(.stale)
        default:
            break
        }

        let result = switch self {
        case .lobby(let lobby): lobby.applying(kind, actorID: actor.id, now: now)
        case .game(let state): state.applying(kind, actorID: actor.id, now: now)
        }
        guard case .applied(let next) = result else { return result }
        let nextRevision = next.revision
        guard nextRevision.tableID == revision.tableID,
              revision.isOlder(than: nextRevision) else {
            return .rejected(.illegalAction)
        }
        return result
    }
}
