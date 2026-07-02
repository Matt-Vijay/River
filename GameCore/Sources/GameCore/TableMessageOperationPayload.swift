import Foundation

public extension TableMessage {
    func applyingOperationPayload(_ payload: String,
                                  knownBy tracker: TableRevisionTracker = TableRevisionTracker(),
                                  now: Date = Date()) throws -> TableOperationResult {
        let operation = try GamePayload.decodeOperation(fromString: payload)
        return applying(operation, knownBy: tracker, now: now)
    }

    func applyingOperationURL(_ url: URL,
                              knownBy tracker: TableRevisionTracker = TableRevisionTracker(),
                              now: Date = Date()) throws -> TableOperationResult {
        let operation = try GamePayload.decodeOperation(from: url)
        return applying(operation, knownBy: tracker, now: now)
    }
}
