import Testing
import Foundation
@testable import GameCore

@Suite("Payload serialization")
struct PayloadSerializationTests {
    @Test("state round-trips through the string form")
    func stringRoundTrip() throws {
        let state = sixPlayerState()
        let encoded = try encodedGame(state)
        let decoded = try decodedGame(from: encoded)
        let encodedObject = try #require(
            JSONSerialization.jsonObject(with: GamePayload.encoder.encode(state)) as? [String: Any]
        )
        let envelope = try #require(
            JSONSerialization.jsonObject(
                with: GamePayload.encoder.encode(TableMessage.game(state))
            ) as? [String: Any]
        )

        #expect(decoded == state)
        #expect(encodedObject["currentBet"] == nil)
        #expect(encodedObject["pot"] as? Int == 0)
        #expect(envelope["wireVersion"] as? Int == 1)
        #expect(envelope["game"] != nil)
        #expect(envelope["lobby"] == nil)
    }

    @Test("decoded results reject malformed best five")
    func decodedResultsRejectMalformedBestFive() throws {
        var result = HandResult(playerID: "p0", amountWon: 10,
                                handName: "Pair", bestFive: cards("Ah Kh Qh Jh Th"))
        result.bestFive = cards("Ah Kh")

        let data = try JSONEncoder().encode(result)
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(HandResult.self, from: data)
        }
    }

    @Test("largest production-shaped tables fit the transport budget")
    func payloadSize() throws {
        var live = sixPlayerState()
        for index in live.players.indices {
            live.players[index].id = String(format: "10000000-0000-0000-0000-%012d", index)
            live.players[index].name = String(repeating: "🂡", count: ProfileText.maxNameLength)
            live.players[index].avatar = String(repeating: "🧑🏿", count: ProfileText.maxAvatarLength)
        }
        let inflatedLive = try GamePayload.encode(.game(live)).utf8.count

        var completed = completedSixPlayerState()
        for index in completed.players.indices {
            completed.players[index].id = String(format: "10000000-0000-0000-0000-%012d", index)
            completed.players[index].name = String(repeating: "🂡", count: ProfileText.maxNameLength)
            completed.players[index].avatar = String(repeating: "🧑🏿", count: ProfileText.maxAvatarLength)
        }
        let inflatedCompleted = try GamePayload.encode(.game(completed)).utf8.count

        let lobby = Lobby(
            tableID: "20000000-0000-0000-0000-000000000000",
            seats: (0..<6).map {
                LobbySeat(
                    id: String(format: "10000000-0000-0000-0000-%012d", $0),
                    name: String(repeating: "🂡", count: ProfileText.maxNameLength),
                    avatar: String(repeating: "🧑🏿", count: ProfileText.maxAvatarLength)
                )
            }
        )
        let inflatedLobby = try GamePayload.encode(.lobby(lobby)).utf8.count
        let productionPayloadBudget = GamePayload.maximumEncodedPayloadLength

        #expect(inflatedLobby < productionPayloadBudget)
        #expect(inflatedLive < productionPayloadBudget)
        #expect(inflatedCompleted < productionPayloadBudget)
    }

    @Test("oversized wire payloads fail before decoding")
    func oversizedPayloadsAreRejected() throws {
        let oversizedWire = String(
            repeating: "A",
            count: GamePayload.maximumEncodedPayloadLength + 1
        )
        #expect(throws: DecodingError.self) {
            _ = try GamePayload.decodeMessage(from: oversizedWire)
        }
    }

    @Test("compressed payloads cannot expand beyond the decode budget")
    func compressedExpansionIsBounded() throws {
        let expanded = Data(repeating: 65, count: GamePayload.maximumDecodedPayloadLength + 1)
        let compressed = try (expanded as NSData).compressed(using: .lzfse) as Data
        let wire = "z" + compressed.base64URLEncodedString()

        #expect(wire.utf8.count < GamePayload.maximumEncodedPayloadLength)
        #expect(throws: DecodingError.self) {
            _ = try GamePayload.decodeMessage(from: wire)
        }
    }

    @Test("compressed payload is URL-safe")
    func urlSafe() throws {
        let encoded = try encodedGame(sixPlayerState())
        #expect(encoded.first == "z")
        #expect(!encoded.contains("+"))
        #expect(!encoded.contains("/"))
        #expect(!encoded.contains("="))
    }

    @Test("decoded game states normalize non-negative table numbers")
    func decodedGameStateNormalizesNonNegativeTableNumbers() throws {
        var state = sixPlayerState()
        state.smallBlind = -5
        state.bigBlind = -10
        state.minRaise = -40
        state.turnDuration = -60
        state.handNumber = -2
        state.version = -7

        let encoded = try encodedGame(state)
        let decoded = try decodedGame(from: encoded)

        #expect(decoded.handNumber == 1)
        #expect(decoded.smallBlind == 1)
        #expect(decoded.bigBlind == 2)
        #expect(decoded.currentBet == 20)
        #expect(decoded.minRaise == 2)
        #expect(decoded.turnDuration == TurnClock.defaultDuration)
        #expect(decoded.version == 0)
    }

    @Test("decoded players normalize non-negative chip fields")
    func decodedPlayersNormalizeNonNegativeChipFields() throws {
        var state = sixPlayerState()
        state.players[0].stack = -100
        state.players[0].bet = -10
        state.players[0].committed = -20
        state.players[0].status = .allIn

        let encoded = try encodedGame(state)
        let decoded = try decodedGame(from: encoded)

        #expect(decoded.players[0].stack == 0)
        #expect(decoded.players[0].bet == 0)
        #expect(decoded.players[0].committed == 0)
    }

    @Test("decoded players normalize profile text")
    func decodedPlayersNormalizeProfileText() throws {
        var state = sixPlayerState()
        state.players[1].name = "  \(String(repeating: "B", count: ProfileText.maxNameLength + 4))  "
        state.players[1].avatar = "  \(String(repeating: "B", count: ProfileText.maxAvatarLength + 4))  "

        let encoded = try encodedGame(state)
        let decoded = try decodedGame(from: encoded)

        #expect(decoded.players[1].name == String(repeating: "B", count: ProfileText.maxNameLength))
        #expect(decoded.players[1].avatar == String(repeating: "B", count: ProfileText.maxAvatarLength))
    }

    @Test("decoded lobby seats normalize profile text")
    func decodedLobbySeatsNormalizeProfileText() throws {
        var lobby = Lobby(seats: [
            LobbySeat(id: "a", name: "Alice", avatar: "A"),
        ])
        lobby.seats[0].name = String(repeating: "L", count: ProfileText.maxNameLength + 4)
        lobby.seats[0].avatar = String(repeating: "A", count: ProfileText.maxAvatarLength + 4)

        let encoded = try GamePayload.encode(TableMessage.lobby(lobby))
        guard case .lobby(let decoded) = try GamePayload.decodeMessage(from: encoded) else {
            Issue.record("expected lobby"); return
        }

        #expect(decoded.seats[0].id == "a")
        #expect(decoded.seats[0].name == String(repeating: "L", count: ProfileText.maxNameLength))
        #expect(decoded.seats[0].avatar == String(repeating: "A", count: ProfileText.maxAvatarLength))
    }

    @Test("decoded live games reject departed active players")
    func decodedLiveGamesRejectDepartedActivePlayers() throws {
        var state = sixPlayerState()
        state.results = nil
        state.players[0].hasLeft = true
        state.players[0].status = .active
        state.currentToAct = 1

        let encoded = try encodedGame(state)
        #expect(throws: DecodingError.self) {
            _ = try decodedGame(from: encoded)
        }
    }

    @Test("decoded completed games reject live betting state")
    func decodedCompletedGamesRejectLiveBettingState() throws {
        var state = completedSixPlayerState()
        state.dealerIndex = -5
        state.street = .turn
        state.currentToAct = 0
        state.turnStartedAt = Date()
        state.players[0].bet = 10
        state.players[0].lastActionBet = 10

        let encoded = try encodedGame(state)
        #expect(throws: DecodingError.self) {
            _ = try decodedGame(from: encoded)
        }
    }

    @Test("decoded live games reject a wire pot that disagrees with committed chips")
    func decodedLiveGameRejectsMismatchedPot() throws {
        let state = sixPlayerState()
        var object = try #require(
            JSONSerialization.jsonObject(with: GamePayload.encoder.encode(state)) as? [String: Any]
        )
        object["pot"] = 1
        let data = try JSONSerialization.data(withJSONObject: object)

        #expect(throws: DecodingError.self) {
            _ = try GamePayload.decoder.decode(GameState.self, from: data)
        }
    }

    @Test("decoded wire payloads reject blank profiles and invalid identities")
    func decodedWirePayloadsRejectBlankProfilesAndInvalidIdentities() throws {
        func game(_ mutate: (inout GameState) -> Void) throws -> String {
            var state = sixPlayerState()
            mutate(&state)
            return try encodedGame(state)
        }

        func lobby(seats: [LobbySeat] = [],
                   _ mutate: (inout Lobby) -> Void) throws -> String {
            var lobby = Lobby(tableID: "valid", seats: seats)
            mutate(&lobby)
            return try GamePayload.encode(.lobby(lobby))
        }

        var rejectedPayloads: [String] = []
        for tableID in ["", " \n "] {
            rejectedPayloads.append(try game { $0.tableID = tableID })
            rejectedPayloads.append(try lobby { $0.tableID = tableID })
        }

        rejectedPayloads.append(try game { $0.players[0].id = " " })
        rejectedPayloads.append(try game {
            $0.players[1].id = $0.players[0].id
        })

        for field in [\Player.name, \Player.avatar] {
            rejectedPayloads.append(try game {
                $0.players[0][keyPath: field] = " \n "
            })
        }

        let seat = LobbySeat(id: "a", name: "Alice", avatar: "A")
        rejectedPayloads.append(try lobby(seats: [seat]) { $0.seats[0].id = "\n" })
        rejectedPayloads.append(try lobby(seats: [
            seat, LobbySeat(id: "b", name: "Bob", avatar: "B")
        ]) {
            $0.seats[1].id = $0.seats[0].id
        })
        rejectedPayloads.append(try lobby { $0.maxPlayers = 99 })
        rejectedPayloads.append(try lobby {
            $0.seats = (0...TableRules.maxPlayers).map {
                LobbySeat(id: "p\($0)", name: "P\($0)", avatar: "P")
            }
        })

        for field in [\LobbySeat.name, \LobbySeat.avatar] {
            rejectedPayloads.append(try lobby(seats: [seat]) {
                $0.seats[0][keyPath: field] = " \n "
            })
        }

        for payload in rejectedPayloads {
            #expect(throws: DecodingError.self) {
                _ = try GamePayload.decodeMessage(from: payload)
            }
        }
    }
}

private func completedSixPlayerState() -> GameState {
    var state = sixPlayerState()
    checkOrCallToShowdown(&state)
    return state
}
