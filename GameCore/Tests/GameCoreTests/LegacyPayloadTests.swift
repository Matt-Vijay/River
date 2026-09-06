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
            removing: ["tableID", "lastActionBet", "version"]
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
        #expect(decodedGame.version == 0)
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
        let wire = try GamePayload.encoder.encode(TableMessage.lobby(lobby))

        guard case .lobby(let decoded) = try GamePayload.decoder.decode(
            SynthesizedTableMessage.self,
            from: wire
        ) else {
            Issue.record("expected lobby")
            return
        }
        #expect(decoded == lobby)
    }

    @Test("wire version one migrates without changing the state revision")
    func wireVersionOneMigrates() throws {
        let original = TableMessage.lobby(
            Lobby(tableID: "table-123")
                .fixtureSeat(id: "a", name: "Alice", avatar: "A")
        )
        var object = try #require(
            JSONSerialization.jsonObject(
                with: GamePayload.encoder.encode(original)
            ) as? [String: Any]
        )
        object["wireVersion"] = 1
        object.removeValue(forKey: "integrity")
        let versionOne = try JSONSerialization.data(
            withJSONObject: object, options: [.sortedKeys]
        ).base64URLEncodedString()

        let decoded = try GamePayload.decodeMessage(from: versionOne)
        let migratedObject = try #require(
            JSONSerialization.jsonObject(with: GamePayload.encoder.encode(decoded)) as? [String: Any]
        )

        #expect(decoded == original)
        #expect(decoded.revision == original.revision)
        #expect(migratedObject["wireVersion"] as? Int == 2)
        #expect((migratedObject["integrity"] as? String)?.count == 64)
    }

    @Test("legacy uncalled winnings migrate to a refund without changing stacks")
    func legacyUncalledWinningsMigrate() throws {
        var state = GameState.startHand(
            players: makePlayers([1_000, 1_000]), dealerIndex: 0,
            smallBlind: 10, bigBlind: 20, seed: 7, handNumber: 1,
            tableID: "legacy-fold"
        )
        let actor = try #require(state.currentToAct)
        let didFold = state.apply(.fold, by: actor)
        #expect(didFold)
        let winnerID = try #require(state.results?.first?.playerID)
        let winnerStack = try #require(state.player(id: winnerID)?.stack)
        #expect(state.results?.first?.amountWon == 20)

        var object = try #require(
            JSONSerialization.jsonObject(
                with: GamePayload.encoder.encode(TableMessage.game(state))
            ) as? [String: Any]
        )
        object["wireVersion"] = 1
        object.removeValue(forKey: "integrity")
        var wrapper = try #require(object["game"] as? [String: Any])
        var game = try #require(wrapper["_0"] as? [String: Any])
        var results = try #require(game["results"] as? [[String: Any]])
        results[0]["amountWon"] = 30
        game["results"] = results
        wrapper["_0"] = game
        object["game"] = wrapper
        let wire = try JSONSerialization.data(
            withJSONObject: object, options: [.sortedKeys]
        ).base64URLEncodedString()

        guard case .game(let migrated) = try GamePayload.decodeMessage(from: wire) else {
            Issue.record("expected migrated game")
            return
        }
        #expect(migrated.results?.first?.amountWon == 20)
        #expect(migrated.displayPot == 20)
        #expect(migrated.player(id: winnerID)?.stack == winnerStack)
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

        object["wireVersion"] = 3
        let future = try JSONSerialization.data(withJSONObject: object)
        #expect(throws: DecodingError.self) {
            _ = try GamePayload.decoder.decode(TableMessage.self, from: future)
        }

        object["wireVersion"] = 1
        object.removeValue(forKey: "integrity")
        object["game"] = object["lobby"]
        let ambiguous = try JSONSerialization.data(withJSONObject: object)
        #expect(throws: DecodingError.self) {
            _ = try GamePayload.decoder.decode(TableMessage.self, from: ambiguous)
        }
    }

    private func legacyEncodedMessage(_ message: TableMessage, removing keys: Set<String>) throws -> String {
        let data = try GamePayload.encoder.encode(message)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let legacyObject = removingKeys(
            keys.union(["wireVersion", "integrity"]), from: object)
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
