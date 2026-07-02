import Foundation
import GameCore

final class LatestRevisionStore {
    private let defaults: UserDefaults
    private let key = "HoldemLatestTableRevisions.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func freshness(of revision: TableRevision) -> TableFreshness {
        tracker().freshness(of: revision)
    }

    func snapshot() -> TableRevisionTracker {
        tracker()
    }

    func remember(_ revision: TableRevision) {
        var next = tracker()
        next.remember(revision)
        save(next)
    }

    private func tracker() -> TableRevisionTracker {
        guard let data = defaults.data(forKey: key) else {
            return TableRevisionTracker()
        }

        let revisions: [TableRevision]
        do {
            revisions = try JSONDecoder().decode([TableRevision].self, from: data)
        } catch {
            defaults.removeObject(forKey: key)
            return TableRevisionTracker()
        }

        return TableRevisionTracker(revisions: revisions)
    }

    private func save(_ tracker: TableRevisionTracker) {
        let revisions = tracker.latestRevisions
        do {
            let data = try JSONEncoder().encode(revisions)
            defaults.set(data, forKey: key)
        } catch {
            defaults.removeObject(forKey: key)
        }
    }
}
