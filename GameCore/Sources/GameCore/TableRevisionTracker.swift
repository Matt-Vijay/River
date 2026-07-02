public enum TableFreshness: Sendable, Equatable {
    case current
    case stale(latest: TableRevision)
}

public struct TableRevisionTracker: Sendable, Equatable {
    public private(set) var latestByTableID: [String: TableRevision]
    public var latestRevisions: [TableRevision] {
        latestByTableID.values.sorted { $0.tableID < $1.tableID }
    }

    public init(latestByTableID: [String: TableRevision] = [:]) {
        self.latestByTableID = [:]
        latestByTableID.values.forEach { remember($0) }
    }

    public init(revisions: [TableRevision]) {
        self.init()
        revisions.forEach { remember($0) }
    }

    public func freshness(of revision: TableRevision) -> TableFreshness {
        guard let latest = latestByTableID[revision.tableID],
              revision.isOlder(than: latest) else {
            return .current
        }
        return .stale(latest: latest)
    }

    public mutating func remember(_ revision: TableRevision) {
        guard let latest = latestByTableID[revision.tableID] else {
            latestByTableID[revision.tableID] = revision
            return
        }
        if latest.isOlder(than: revision) {
            latestByTableID[revision.tableID] = revision
        }
    }
}
