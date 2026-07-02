import Foundation

public extension GamePayload {
    static func encodeOperationToString(_ operation: TableOperation) throws -> String {
        try encodeToPayload(operation)
    }

    static func decodeOperation(fromString string: String) throws -> TableOperation {
        try decodePayload(TableOperation.self, from: string)
    }

    static func encodeOperationToURL(_ operation: TableOperation) throws -> URL {
        try makeURL(host: "operation", payload: operation)
    }

    static func decodeOperation(from url: URL) throws -> TableOperation {
        try decodePayload(TableOperation.self,
                          from: payloadString(in: url, host: "operation",
                                              description: "No operation payload in URL"))
    }
}
