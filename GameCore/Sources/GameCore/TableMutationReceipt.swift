import CryptoKit
import Foundation

/// Replay evidence for one successful table mutation. It is deliberately kept
/// outside `TableMessage` so old state payloads remain unchanged and receipt
/// data never gains authority merely by being received.
public struct TableMutationReceipt: Codable, Sendable, Equatable {
    public static let maximumEncodedLength = 1_024
    private static let currentVersion = 1

    public struct StateReference: Codable, Sendable, Equatable {
        private enum CodingKeys: String, CodingKey { case revision = "r", fingerprint = "f" }

        public let revision: TableRevision
        public let fingerprint: String

        fileprivate init?(_ message: TableMessage) {
            let fingerprint = GamePayload.stateFingerprint(for: message)
            guard Self.isFingerprint(fingerprint) else { return nil }
            revision = message.revision
            self.fingerprint = fingerprint
        }

        fileprivate var isValid: Bool {
            revision.version >= 0 && Self.isFingerprint(fingerprint)
        }

        fileprivate func matches(_ message: TableMessage) -> Bool {
            revision == message.revision
                && fingerprint == GamePayload.stateFingerprint(for: message)
        }

        private static func isFingerprint(_ value: String) -> Bool {
            value.utf8.count == 32 && value.utf8.allSatisfy {
                (48...57).contains($0) || (97...102).contains($0)
            }
        }
    }

    private struct Body: Codable, Sendable, Equatable {
        private enum CodingKeys: String, CodingKey {
            case version = "v", actorID = "a", parent = "p", operation = "o"
            case timeBits = "t", result = "r"
        }

        let version: Int
        let actorID: String
        let parent: StateReference
        let operation: TableOperation
        let timeBits: UInt64
        let result: StateReference
    }

    private struct Wire: Codable {
        private enum CodingKeys: String, CodingKey { case body = "b", integrity = "h" }
        let body: Body
        let integrity: String
    }

    private let body: Body
    private let integrity: String

    public var actorID: String { body.actorID }
    public var parent: StateReference { body.parent }
    public var operation: TableOperation { body.operation }
    public var result: StateReference { body.result }
    public var parentRevision: TableRevision { body.parent.revision }
    public var resultRevision: TableRevision { body.result.revision }
    public var parentFingerprint: String { body.parent.fingerprint }
    public var resultFingerprint: String { body.result.fingerprint }
    public var appliedAt: Date {
        Date(timeIntervalSinceReferenceDate: Double(bitPattern: body.timeBits))
    }

    /// Internal so tests can make a well-sealed false result claim and prove
    /// that replay, rather than only the integrity digest, rejects it.
    init?(
        actor: TableActor,
        parent: TableMessage,
        operation: TableOperation,
        appliedAt: Date,
        claimedResult: TableMessage
    ) {
        guard appliedAt.timeIntervalSinceReferenceDate.isFinite,
              let parent = StateReference(parent),
              let result = StateReference(claimedResult),
              parent.revision.tableID == result.revision.tableID,
              parent.revision.isOlder(than: result.revision) else { return nil }
        let body = Body(
            version: Self.currentVersion,
            actorID: actor.id,
            parent: parent,
            operation: operation,
            timeBits: appliedAt.timeIntervalSinceReferenceDate.bitPattern,
            result: result
        )
        guard let integrity = try? Self.digest(body) else { return nil }
        self.body = body
        self.integrity = integrity
        guard (try? encoded().count).map({ $0 <= Self.maximumEncodedLength }) == true else {
            return nil
        }
    }

    public init(from decoder: Decoder) throws {
        let wire = try Wire(from: decoder)
        guard Self.isValid(wire) else { throw CodingFailure.invalidPayload }
        body = wire.body
        integrity = wire.integrity
    }

    public func encode(to encoder: Encoder) throws {
        try Wire(body: body, integrity: integrity).encode(to: encoder)
    }

    public func encoded() throws -> Data {
        let data = try GamePayload.encoder.encode(self)
        guard data.count <= Self.maximumEncodedLength else { throw CodingFailure.payloadTooLarge }
        return data
    }

    /// Size-gated canonical decoding rejects extra fields, unsupported versions,
    /// malformed values, and integrity-modified receipt payloads.
    public static func decode(from data: Data) throws -> Self {
        guard !data.isEmpty else { throw CodingFailure.emptyPayload }
        guard data.count <= maximumEncodedLength else { throw CodingFailure.payloadTooLarge }
        let receipt = try GamePayload.decoder.decode(Self.self, from: data)
        guard try GamePayload.encoder.encode(receipt) == data else {
            throw CodingFailure.invalidPayload
        }
        return receipt
    }

    public enum CodingFailure: Error, Sendable, Equatable {
        case emptyPayload
        case payloadTooLarge
        case invalidPayload
    }

    private static func isValid(_ wire: Wire) -> Bool {
        guard wire.body.version == currentVersion,
              TableActor(wire.body.actorID)?.id == wire.body.actorID,
              Double(bitPattern: wire.body.timeBits).isFinite,
              wire.body.parent.isValid,
              wire.body.result.isValid,
              wire.body.parent.revision.tableID == wire.body.result.revision.tableID,
              wire.body.parent.revision.isOlder(than: wire.body.result.revision),
              let expected = try? digest(wire.body) else { return false }
        return constantTimeEqual(wire.integrity, expected)
    }

    private static func digest(_ body: Body) throws -> String {
        var data = Data("river-table-mutation-v1\u{0}".utf8)
        data.append(try GamePayload.encoder.encode(body))
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func constantTimeEqual(_ lhs: String, _ rhs: String) -> Bool {
        guard lhs.utf8.count == rhs.utf8.count else { return false }
        return zip(lhs.utf8, rhs.utf8).reduce(UInt8(0)) { $0 | ($1.0 ^ $1.1) } == 0
    }
}

public enum TableMutationRecordingResult: Sendable, Equatable {
    case applied(TableMessage, TableMutationReceipt)
    case unchanged
    case rejected(TableOperationRejection)
    case unrecordable
}

public enum TableMutationVerificationRejection: Sendable, Equatable {
    case tampered
    case wrongActor
    case wrongTable
    case wrongParent
    case operationUnchanged
    case operationRejected(TableOperationRejection)
    case wrongResult
}

public enum TableMutationVerificationResult: Sendable, Equatable {
    case verified(TableMessage)
    case rejected(TableMutationVerificationRejection)
}

public extension TableMutationReceipt {
    /// Checks that the receipt names this exact successor. This validates the
    /// sealed revision and state fingerprint but does not authenticate the
    /// actor or prove that the operation was legal; callers still need a local
    /// participant identity and, when available, `verifying(predecessor:...)`.
    func matchesResult(_ message: TableMessage) -> Bool {
        Self.isValid(Wire(body: body, integrity: integrity))
            && result.matches(message)
    }

    static func recording(
        _ operation: TableOperation,
        on predecessor: TableMessage,
        actor: TableActor,
        latestRevision: TableRevision? = nil,
        at appliedAt: Date = Date()
    ) -> TableMutationRecordingResult {
        guard appliedAt.timeIntervalSinceReferenceDate.isFinite else { return .unrecordable }
        switch predecessor.committing(
            operation, actor: actor, latestRevision: latestRevision, now: appliedAt
        ) {
        case .unchanged:
            return .unchanged
        case .rejected(let rejection):
            return .rejected(rejection)
        case .applied(let next):
            guard let receipt = Self(
                actor: actor,
                parent: predecessor,
                operation: operation,
                appliedAt: appliedAt,
                claimedResult: next
            ) else { return .unrecordable }
            return .applied(next, receipt)
        }
    }

    /// `authenticatedActor` must be derived locally (for example, from
    /// `MSMessage.senderParticipantIdentifier`), never trusted from the receipt.
    func verifying(
        predecessor: TableMessage,
        authenticatedActor: TableActor
    ) -> TableMutationVerificationResult {
        guard Self.isValid(Wire(body: body, integrity: integrity)) else {
            return .rejected(.tampered)
        }
        guard actorID == authenticatedActor.id else { return .rejected(.wrongActor) }
        guard predecessor.revision.tableID == parentRevision.tableID else {
            return .rejected(.wrongTable)
        }
        guard parent.matches(predecessor) else { return .rejected(.wrongParent) }

        switch predecessor.committing(
            operation,
            actor: authenticatedActor,
            latestRevision: parentRevision,
            now: appliedAt
        ) {
        case .unchanged:
            return .rejected(.operationUnchanged)
        case .rejected(let rejection):
            return .rejected(.operationRejected(rejection))
        case .applied(let replayed):
            return result.matches(replayed)
                ? .verified(replayed)
                : .rejected(.wrongResult)
        }
    }
}
