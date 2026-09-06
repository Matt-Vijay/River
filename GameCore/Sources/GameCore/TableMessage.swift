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
                let ending = "-\(suffix)"
                var prefix = base
                while prefix.utf8.count + ending.utf8.count > maximumUTF8Length {
                    prefix.removeLast()
                }
                candidate = prefix + ending
                suffix += 1
            }
            copy.id = candidate
            return copy
        }
    }
}

/// A table seat authorized by the caller's local identity or sender binding.
public struct TableActor: Sendable, Equatable, Hashable {
    public let id: String

    public init?(_ id: String) {
        guard let id = Identity.actor(id) else { return nil }
        self.id = id
    }
}

/// Messages UUIDs differ across devices. Bind each locally observed sender to
/// their advertised table seat on first contact, then reject changed bindings.
/// This is trust-on-first-use for casual play, not cryptographic identity proof.
public struct TableParticipants: Codable, Sendable, Equatable {
    private var seats: [String: String] = [:]

    public init() {}

    public mutating func bind(_ actor: TableActor, senderID: String, localID: String) -> Bool {
        if senderID == localID { return actor.id == localID }
        guard actor.id != localID else { return false }
        if let known = seats[senderID] { return known == actor.id }
        guard !seats.values.contains(actor.id) else { return false }
        seats[senderID] = actor.id
        return true
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
        // Equal-version branches use a deterministic tie-break. An empty legacy
        // fingerprint sorts before every current fingerprint automatically.
        tableID == other.tableID
            && (phase.rawValue, version, branch) < (other.phase.rawValue, other.version, other.branch)
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

/// What a conversation's message carries: either the lobby (pre-game) or a live
/// game state. The whole thing travels in the `MSMessage.url`.
public enum TableMessage: Sendable, Equatable {
    case lobby(Lobby)
    case game(GameState)
}

extension TableMessage: Codable {
    private static let currentWireVersion = 2

    private enum CodingKeys: String, CodingKey, CaseIterable { case wireVersion, integrity, lobby, game }
    private enum PayloadCodingKeys: String, CodingKey, CaseIterable { case value = "_0" }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(validatingKeys: CodingKeys.self)
        let wireVersion = try container.decodeIfPresent(Int.self, forKey: .wireVersion) ?? 0
        guard (0...Self.currentWireVersion).contains(wireVersion) else {
            throw DecodingError.dataCorruptedError(
                forKey: .wireVersion, in: container,
                debugDescription: "Unsupported table message wire version")
        }
        let decoded: TableMessage
        switch (container.contains(.lobby), container.contains(.game)) {
        case (true, false):
            let payload = try container.superDecoder(forKey: .lobby)
                .container(validatingKeys: PayloadCodingKeys.self)
            decoded = .lobby(try payload.decode(Lobby.self, forKey: .value))
        case (false, true):
            let payload = try container.superDecoder(forKey: .game)
                .container(validatingKeys: PayloadCodingKeys.self)
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
        if let latestRevision, !revision.isSameOrNewer(than: latestRevision) {
            return .rejected(.stale)
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
