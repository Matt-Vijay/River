import Foundation

@MainActor
public final class TableHistory {
    private struct Record: Codable {
        let id: String
        var url: URL
        var bindings: [String: String]
    }

    // A malformed entry must not discard unrelated tables or their sender bindings.
    private struct DecodedRecord<Value: Decodable>: Decodable {
        let record: Value?
        init(from decoder: Decoder) { record = try? Value(from: decoder) }
    }

    private struct LegacyRecord: Decodable {
        struct Revision: Decodable { let tableID: String; let phase: Int; let version: Int; let branch: String }
        struct Participants: Decodable { let seats: [String: String] }
        let tableID: String
        let revision: Revision?
        let participants: Participants
    }

    private let defaults: UserDefaults
    private static let key = "river.tables.v2"
    private var records: [Record]

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        records = defaults.data(forKey: Self.key)
            .flatMap { try? JSONDecoder().decode([DecodedRecord<Record>].self, from: $0) }
            .map { Array($0.compactMap(\.record).suffix(32)) } ?? []
    }

    public func latest(_ id: String) -> TableMessage? {
        guard let record = records.first(where: { $0.id == id }),
              let message = try? TableMessage(url: record.url), message.table.id == id else { return nil }
        return message
    }

    /// A Messages UUID has meaning only on this device. Learn its seat once;
    /// later messages cannot rename that sender or impersonate another seat.
    public func accept(_ incoming: TableMessage, sender: String, localID: String) throws -> TableMessage {
        guard Table.validID(sender), Table.validID(localID) else { throw TableError.invalidPlayer }
        let prior = latest(incoming.table.id)
        if let prior, incoming.move.parent == prior.fingerprint, !incoming.verifies(after: prior.table) {
            throw TableError.invalidState
        }
        // A stale bubble only reopens known state; it must not establish new sender bindings.
        if let prior, !incoming.isNewer(than: prior) { return prior }
        let url = try incoming.url()
        let legacy = prior == nil ? defaults.data(forKey: "RiverTableHistory.v1")
            .flatMap { try? JSONDecoder().decode([DecodedRecord<LegacyRecord>].self, from: $0) }
            .flatMap { $0.lazy.compactMap(\.record).first { $0.tableID == incoming.table.id } } : nil
        var knownLocalEcho = false
        if let branch = incoming.legacyBranch, let revision = legacy?.revision {
            let current = (incoming.table.hand == nil ? 0 : 1, incoming.table.version, branch)
            guard revision.tableID == incoming.table.id,
                  current >= (revision.phase, revision.version, revision.branch) else { throw TableError.stale }
            knownLocalEcho = incoming.move.actor == localID
                && current == (revision.phase, revision.version, revision.branch)
        }
        var record = records.first { $0.id == incoming.table.id }
            ?? Record(id: incoming.table.id, url: url, bindings: legacy?.participants.seats ?? [:])
        let actor = incoming.move.actor
        if sender == localID {
            guard actor == localID else { throw TableError.invalidPlayer }
        } else if !knownLocalEcho {
            guard actor != localID else { throw TableError.invalidPlayer }
            if let bound = record.bindings[sender] {
                guard bound == actor else { throw TableError.invalidPlayer }
            } else {
                guard !record.bindings.values.contains(actor) else { throw TableError.invalidPlayer }
                record.bindings[sender] = actor
            }
        }
        record.url = url
        records.removeAll { $0.id == record.id }
        records.append(record)
        records = Array(records.suffix(32))
        defaults.set(try JSONEncoder().encode(records), forKey: Self.key)
        return incoming
    }
}
