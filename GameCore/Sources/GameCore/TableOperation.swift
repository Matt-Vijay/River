import Foundation

public struct TableOperation: Sendable, Equatable {
    public var id: String
    public var actorID: String
    public var baseRevision: TableRevision
    public var kind: Kind

    public init(id: String, actorID: String, baseRevision: TableRevision, kind: Kind) {
        self.id = OperationIdentity.normalized(id)
        self.actorID = actorID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.baseRevision = baseRevision
        self.kind = kind.normalized
    }
}

private enum TableOperationCodingKeys: String, CodingKey {
    case id, actorID, baseRevision, kind
}

extension TableOperation: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: TableOperationCodingKeys.self)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            actorID: try container.decode(String.self, forKey: .actorID),
            baseRevision: try container.decode(TableRevision.self, forKey: .baseRevision),
            kind: try container.decode(Kind.self, forKey: .kind)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: TableOperationCodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(actorID, forKey: .actorID)
        try container.encode(baseRevision, forKey: .baseRevision)
        try container.encode(kind, forKey: .kind)
    }
}
