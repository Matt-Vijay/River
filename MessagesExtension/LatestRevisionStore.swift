import Foundation
import GameCore

final class LatestRevisionStore {
    private static let limit = 64
    private let defaults: UserDefaults
    private let key = "HoldemLatestTableRevisions.v1"
    private lazy var revisions = loadRevisions()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func latest(for tableID: String) -> TableRevision? {
        revisions.first { $0.tableID == tableID }
    }

    @discardableResult
    func observe(_ revision: TableRevision) -> Bool {
        if let index = revisions.firstIndex(where: { $0.tableID == revision.tableID }) {
            let latest = revisions[index]
            guard revision.isSameOrNewer(than: latest) else { return false }
            guard revision != latest else { return true }
            revisions.remove(at: index)
        }
        revisions.append(revision)
        revisions = Array(revisions.suffix(Self.limit))
        if let data = try? JSONEncoder().encode(revisions) {
            defaults.set(data, forKey: key)
        }
        return true
    }

    private func loadRevisions() -> [TableRevision] {
        guard let data = defaults.data(forKey: key),
              let revisions = try? JSONDecoder().decode([TableRevision].self, from: data) else {
            defaults.removeObject(forKey: key)
            return []
        }
        var normalized: [TableRevision] = []
        for revision in revisions {
            if let index = normalized.firstIndex(where: { $0.tableID == revision.tableID }) {
                guard revision.isSameOrNewer(than: normalized[index]) else { continue }
                normalized.remove(at: index)
            }
            normalized.append(revision)
        }
        return Array(normalized.suffix(Self.limit))
    }
}
