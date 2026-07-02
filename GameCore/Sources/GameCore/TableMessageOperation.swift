import Foundation

public extension TableMessage {
    func applying(_ operation: TableOperation, knownBy tracker: TableRevisionTracker,
                  now: Date = Date()) -> TableOperationResult {
        guard operation.baseRevision.tableID == revision.tableID else {
            return .rejected(.wrongTable)
        }
        guard !operation.id.isEmpty else {
            return .rejected(.invalidOperationIdentity)
        }
        guard !appliedOperationIDs.contains(operation.id) else {
            return .unchanged(self)
        }
        if case .stale(let latest) = tracker.freshness(of: revision) {
            return .rejected(.stale(expected: latest))
        }
        return applying(operation, now: now)
    }

    func applying(_ operation: TableOperation, now: Date = Date()) -> TableOperationResult {
        guard operation.baseRevision.tableID == revision.tableID else {
            return .rejected(.wrongTable)
        }
        guard !operation.id.isEmpty else {
            return .rejected(.invalidOperationIdentity)
        }
        guard !appliedOperationIDs.contains(operation.id) else {
            return .unchanged(self)
        }
        guard operation.baseRevision == revision else {
            return .rejected(.stale(expected: revision))
        }
        guard !operation.actorID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .rejected(.notSeated)
        }

        switch self {
        case .lobby(let lobby):
            return lobby.applying(operation, now: now)
        case .game(let state):
            return state.applying(operation, now: now)
        }
    }
}
