import Foundation

public extension GamePayload {
    static func encodeToString(_ state: GameState) throws -> String {
        try encodeToPayload(state)
    }

    static func decode(fromString string: String) throws -> GameState {
        try decodePayload(GameState.self, from: string)
    }

    static func encodeToURL(_ state: GameState) throws -> URL {
        try makeURL(host: "game", payload: state)
    }

    static func decode(from url: URL) throws -> GameState {
        try decodePayload(GameState.self,
                          from: payloadString(in: url, host: "game",
                                              description: "No game payload in URL"))
    }
}
