import Foundation

public extension TableMessage {
    func committing(_ kind: TableOperation.Kind,
                    actorID: String,
                    operationID: String,
                    knownBy tracker: TableRevisionTracker = TableRevisionTracker(),
                    now: Date = Date()) throws -> TableOperationResult {
        let operation = TableOperation(id: operationID,
                                       actorID: actorID,
                                       baseRevision: revision,
                                       kind: kind)
        let payload = try GamePayload.encodeOperationToString(operation)
        return try applyingOperationPayload(payload, knownBy: tracker, now: now)
    }
}
