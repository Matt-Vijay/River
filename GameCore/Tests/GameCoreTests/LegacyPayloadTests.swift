import Testing
import Foundation
@testable import GameCore

@Suite("Legacy payloads")
struct LegacyPayloadTests {
    private static let frozenPreVersionLobby = #"{"lobby":{"_0":{"bigBlind":10,"maxPlayers":6,"seats":[],"smallBlind":5,"startingStack":1000}}}"#

    private enum SynthesizedTableMessage: Codable {
        case lobby(Lobby)
        case game(GameState)
    }

    @Test("legacy payloads without table identity still decode")
    func legacyPayloadsDecode() throws {
        let lobby = Lobby(tableID: "table-123")
            .fixtureSeat(id: "a", name: "Alice", avatar: "🙂")
        let legacyLobby = try legacyEncodedMessage(TableMessage.lobby(lobby), removing: ["tableID", "version"])
        guard case .lobby(let decodedLobby) = try GamePayload.decodeMessage(from: legacyLobby) else {
            Issue.record("expected lobby")
            return
        }
        guard case .lobby(let decodedLobbyAgain) = try GamePayload.decodeMessage(from: legacyLobby) else {
            Issue.record("expected lobby")
            return
        }
        #expect(!decodedLobby.tableID.isEmpty)
        #expect(decodedLobby.tableID == decodedLobbyAgain.tableID)
        #expect(decodedLobby.version == 0)
        let migratedLobby = try GamePayload.encode(TableMessage.lobby(decodedLobby))
        guard case .lobby(let migratedLobbyAgain) = try GamePayload.decodeMessage(from: migratedLobby) else {
            Issue.record("expected lobby")
            return
        }
        #expect(migratedLobbyAgain.tableID == decodedLobby.tableID)

        var state = sixPlayerState()
        let actor = try #require(state.currentToAct)
        let legal = state.legalActions(for: actor)
        state.apply(
            legal.canCheck ? .check : .call,
            by: actor,
            now: state.turnStartedAt ?? .distantPast
        )
        let legacyGame = try legacyEncodedMessage(
            TableMessage.game(state),
            removing: ["tableID", "lastActionBet"]
        )
        guard case .game(let decodedGame) = try GamePayload.decodeMessage(from: legacyGame) else {
            Issue.record("expected game")
            return
        }
        guard case .game(let decodedGameAgain) = try GamePayload.decodeMessage(from: legacyGame) else {
            Issue.record("expected game")
            return
        }
        #expect(!decodedGame.tableID.isEmpty)
        #expect(decodedGame.tableID == decodedGameAgain.tableID)
        #expect(decodedGame.version == state.version)
        #expect(decodedGame.players.map(\.lastActionBet) == state.players.map(\.lastActionBet))
        let migratedGame = try GamePayload.encode(TableMessage.game(decodedGame))
        guard case .game(let migratedGameAgain) = try GamePayload.decodeMessage(from: migratedGame) else {
            Issue.record("expected game")
            return
        }
        #expect(migratedGameAgain.tableID == decodedGame.tableID)
    }

    @Test("versioned payloads remain readable by the previous synthesized decoder")
    func versionedPayloadsRemainBackwardCompatible() throws {
        let lobby = Lobby(tableID: "table-123")
            .fixtureSeat(id: "a", name: "Alice", avatar: "A")
        let wire = try decodedWire(GamePayload.encode(.lobby(lobby)))

        guard case .lobby(let decoded) = try GamePayload.decoder.decode(
            SynthesizedTableMessage.self,
            from: wire
        ) else {
            Issue.record("expected lobby")
            return
        }
        #expect(decoded == lobby)
    }

    @Test("frozen pre-version payload remains readable")
    func frozenPreVersionPayloadRemainsReadable() throws {
        let wire = Data(Self.frozenPreVersionLobby.utf8).base64URLEncodedString()

        guard case .lobby(let decoded) = try GamePayload.decodeMessage(from: wire) else {
            Issue.record("expected lobby")
            return
        }
        #expect(decoded.tableID.hasPrefix("legacy-v1-"))
        #expect(decoded.version == 0)
        #expect(decoded.seats.isEmpty)
        #expect(decoded.maxPlayers == 6)
        #expect(decoded.smallBlind == 5)
        #expect(decoded.bigBlind == 10)
        #expect(decoded.startingStack == 1_000)
    }

    @Test("unknown wire versions and ambiguous envelopes are rejected")
    func invalidEnvelopesAreRejected() throws {
        let lobby = Lobby(tableID: "table-123")
        let encoded = try GamePayload.encoder.encode(TableMessage.lobby(lobby))
        var object = try #require(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )

        object["wireVersion"] = 2
        let future = try JSONSerialization.data(withJSONObject: object)
        #expect(throws: DecodingError.self) {
            _ = try GamePayload.decoder.decode(TableMessage.self, from: future)
        }

        object["wireVersion"] = 1
        object["game"] = object["lobby"]
        let ambiguous = try JSONSerialization.data(withJSONObject: object)
        #expect(throws: DecodingError.self) {
            _ = try GamePayload.decoder.decode(TableMessage.self, from: ambiguous)
        }
    }

    private func legacyEncodedMessage(_ message: TableMessage, removing keys: Set<String>) throws -> String {
        let encoded = try GamePayload.encode(message)
        let data = try decodedWire(encoded)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let legacyObject = removingKeys(keys.union(["wireVersion"]), from: object)
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject, options: [.sortedKeys])
        return legacyData.base64URLEncodedString()
    }

    private func decodedWire(_ encoded: String) throws -> Data {
        let isCompressed = encoded.first == "z"
        let payload = isCompressed ? String(encoded.dropFirst()) : encoded
        let data = try #require(Data(base64URLEncoded: payload))
        return try isCompressed
            ? (data as NSData).decompressed(using: .lzfse) as Data
            : data
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
