import Testing
import Foundation
@testable import GameCore

@Suite("Legacy payloads")
struct LegacyPayloadTests {
    @Test("legacy payloads without table identity still decode")
    func legacyPayloadsDecode() throws {
        let lobby = Lobby(tableID: "table-123")
            .adding(id: "a", name: "Alice", avatar: "🙂")
        let legacyLobby = try legacyEncodedMessage(TableMessage.lobby(lobby), removing: ["tableID", "version"])
        guard case .lobby(let decodedLobby) = try GamePayload.decodeMessage(fromString: legacyLobby) else {
            Issue.record("expected lobby")
            return
        }
        #expect(!decodedLobby.tableID.isEmpty)
        #expect(decodedLobby.version == 0)

        let state = sixPlayerState()
        let legacyGame = try legacyEncodedMessage(TableMessage.game(state), removing: ["tableID"])
        guard case .game(let decodedGame) = try GamePayload.decodeMessage(fromString: legacyGame) else {
            Issue.record("expected game")
            return
        }
        #expect(!decodedGame.tableID.isEmpty)
        #expect(decodedGame.version == state.version)
    }

    private func legacyEncodedMessage(_ message: TableMessage, removing keys: Set<String>) throws -> String {
        let encoded = try GamePayload.encodeToString(message)
        let data = try #require(Data(base64URLEncoded: encoded))
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let legacyObject = removingKeys(keys, from: object)
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject, options: [.sortedKeys])
        return legacyData.base64URLEncodedString()
    }

    private func removingKeys(_ keys: Set<String>, from object: Any) -> Any {
        if var dictionary = object as? [String: Any] {
            for key in keys { dictionary.removeValue(forKey: key) }
            for (key, value) in dictionary {
                dictionary[key] = removingKeys(keys, from: value)
            }
            return dictionary
        }
        if let array = object as? [Any] {
            return array.map { removingKeys(keys, from: $0) }
        }
        return object
    }
}
