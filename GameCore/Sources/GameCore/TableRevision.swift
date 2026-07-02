import Foundation

public struct TableRevision: Sendable, Equatable {
    public enum Phase: Int, Codable, Sendable {
        case lobby = 0
        case game = 1
    }

    public var tableID: String
    public var phase: Phase
    public var version: Int

    public init(tableID: String, phase: Phase, version: Int) {
        self.tableID = TableIdentity.normalized(tableID)
        self.phase = phase
        self.version = max(0, version)
    }

    public func isOlder(than other: TableRevision) -> Bool {
        guard tableID == other.tableID else { return false }
        if phase != other.phase { return phase.rawValue < other.phase.rawValue }
        return version < other.version
    }
}

private enum TableRevisionCodingKeys: String, CodingKey {
    case tableID, phase, version
}

extension TableRevision: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: TableRevisionCodingKeys.self)
        tableID = TableIdentity.normalized(try container.decode(String.self, forKey: .tableID))
        phase = try container.decode(Phase.self, forKey: .phase)
        version = max(0, try container.decode(Int.self, forKey: .version))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: TableRevisionCodingKeys.self)
        try container.encode(tableID, forKey: .tableID)
        try container.encode(phase, forKey: .phase)
        try container.encode(version, forKey: .version)
    }
}
