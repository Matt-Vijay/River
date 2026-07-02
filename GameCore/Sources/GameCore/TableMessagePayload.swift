import Foundation

public extension GamePayload {
    static func encodeToString(_ message: TableMessage) throws -> String {
        try encodeToPayload(message)
    }

    static func decodeMessage(fromString string: String) throws -> TableMessage {
        try decodePayload(TableMessage.self, from: string)
    }

    static func encodeToURL(_ message: TableMessage) throws -> URL {
        try makeURL(host: "table", payload: message)
    }

    static func decodeMessage(from url: URL) throws -> TableMessage {
        try decodePayload(TableMessage.self,
                          from: payloadString(in: url, host: "table",
                                              description: "No table payload in URL"))
    }
}
