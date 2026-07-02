import Testing
import Foundation
@testable import GameCore

@Suite("Payload serialization")
struct PayloadSerializationTests {
    @Test("state round-trips through the string form")
    func stringRoundTrip() throws {
        let state = sixPlayerState()
        let encoded = try GamePayload.encodeToString(state)
        let decoded = try GamePayload.decode(fromString: encoded)
        #expect(decoded == state)
    }

    @Test("state round-trips through the URL form")
    func urlRoundTrip() throws {
        let state = sixPlayerState()
        let url = try GamePayload.encodeToURL(state)
        let decoded = try GamePayload.decode(from: url)
        #expect(decoded == state)
    }

    @Test("six-player payload fits comfortably in a message URL")
    func payloadSize() throws {
        let url = try GamePayload.encodeToURL(sixPlayerState())
        let length = url.absoluteString.count
        // Plenty of headroom; iMessage URLs handle a few KB without trouble.
        #expect(length < 4000)
    }

    @Test("payload is URL-safe (no characters needing escaping)")
    func urlSafe() throws {
        let encoded = try GamePayload.encodeToString(sixPlayerState())
        #expect(!encoded.contains("+"))
        #expect(!encoded.contains("/"))
        #expect(!encoded.contains("="))
    }

    @Test("URL decoding rejects URLs without a payload query item")
    func urlRequiresPayloadQueryItem() throws {
        let url = try #require(URL(string: "holdem://game?x=missing"))

        #expect(throws: DecodingError.self) {
            _ = try GamePayload.decode(from: url)
        }
    }

    @Test("URL decoding rejects ambiguous duplicate payload query items")
    func urlRejectsDuplicatePayloadQueryItems() throws {
        let first = try GamePayload.encodeToString(sixPlayerState())
        let second = try GamePayload.encodeToString(TableMessage.lobby(Lobby(tableID: "table-123")))
        let url = try #require(URL(string: "holdem://game?g=\(first)&g=\(second)"))

        #expect(throws: DecodingError.self) {
            _ = try GamePayload.decode(from: url)
        }
    }

    @Test("state URL decoding rejects non-game routes")
    func stateURLDecodingRejectsNonGameRoutes() throws {
        let encoded = try GamePayload.encodeToString(sixPlayerState())
        let url = try #require(URL(string: "holdem://table?g=\(encoded)"))

        #expect(throws: DecodingError.self) {
            _ = try GamePayload.decode(from: url)
        }
    }

    @Test("state URL decoding rejects non-holdem schemes")
    func stateURLDecodingRejectsNonHoldemSchemes() throws {
        let encoded = try GamePayload.encodeToString(sixPlayerState())
        let url = try #require(URL(string: "https://game?g=\(encoded)"))

        #expect(throws: DecodingError.self) {
            _ = try GamePayload.decode(from: url)
        }
    }

    @Test("table message URL decoding rejects non-table routes")
    func tableMessageURLDecodingRejectsNonTableRoutes() throws {
        let message = TableMessage.lobby(Lobby(tableID: "table-123"))
        let encoded = try GamePayload.encodeToString(message)
        let url = try #require(URL(string: "holdem://operation?g=\(encoded)"))

        #expect(throws: DecodingError.self) {
            _ = try GamePayload.decodeMessage(from: url)
        }
    }

    @Test("table message URL decoding rejects non-holdem schemes")
    func tableMessageURLDecodingRejectsNonHoldemSchemes() throws {
        let message = TableMessage.lobby(Lobby(tableID: "table-123"))
        let encoded = try GamePayload.encodeToString(message)
        let url = try #require(URL(string: "https://table?g=\(encoded)"))

        #expect(throws: DecodingError.self) {
            _ = try GamePayload.decodeMessage(from: url)
        }
    }

    @Test("operation envelopes round-trip through string and URL payloads")
    func operationEnvelopeRoundTripsThroughPayloads() throws {
        let revision = TableRevision(tableID: "table-123", phase: .game, version: 7)
        let operation = TableOperation(id: "  op-1  ",
                                       actorID: "  player-a  ",
                                       baseRevision: revision,
                                       kind: .gameAction(.raise(to: -20)))

        let encoded = try GamePayload.encodeOperationToString(operation)
        let decoded = try GamePayload.decodeOperation(fromString: encoded)
        let url = try GamePayload.encodeOperationToURL(operation)
        let decodedURL = try GamePayload.decodeOperation(from: url)

        #expect(!encoded.contains("+"))
        #expect(!encoded.contains("/"))
        #expect(!encoded.contains("="))
        #expect(url.host == "operation")
        #expect(decoded == operation)
        #expect(decodedURL == operation)
        #expect(decoded.id == "op-1")
        #expect(decoded.actorID == "player-a")
        #expect(decoded.kind == .gameAction(.raise(to: 0)))
        #expect(decoded.baseRevision == revision)
    }

    @Test("operation URL decoding rejects non-operation routes")
    func operationURLDecodingRejectsNonOperationRoutes() throws {
        let revision = TableRevision(tableID: "table-123", phase: .game, version: 7)
        let operation = TableOperation(id: "op-1",
                                       actorID: "player-a",
                                       baseRevision: revision,
                                       kind: .gameAction(.fold))
        let encoded = try GamePayload.encodeOperationToString(operation)
        let url = try #require(URL(string: "holdem://table?g=\(encoded)"))

        #expect(throws: DecodingError.self) {
            _ = try GamePayload.decodeOperation(from: url)
        }
    }

    @Test("operation URL decoding rejects non-holdem schemes")
    func operationURLDecodingRejectsNonHoldemSchemes() throws {
        let revision = TableRevision(tableID: "table-123", phase: .game, version: 7)
        let operation = TableOperation(id: "op-1",
                                       actorID: "player-a",
                                       baseRevision: revision,
                                       kind: .gameAction(.fold))
        let encoded = try GamePayload.encodeOperationToString(operation)
        let url = try #require(URL(string: "https://operation?g=\(encoded)"))

        #expect(throws: DecodingError.self) {
            _ = try GamePayload.decodeOperation(from: url)
        }
    }

    @Test("decoded game states normalize non-negative table numbers")
    func decodedGameStateNormalizesNonNegativeTableNumbers() throws {
        var state = sixPlayerState()
        state.smallBlind = -5
        state.bigBlind = -10
        state.pot = -20
        state.currentBet = -30
        state.minRaise = -40
        state.turnDuration = -60
        state.handNumber = -2
        state.version = -7

        let encoded = try GamePayload.encodeToString(state)
        let decoded = try GamePayload.decode(fromString: encoded)

        #expect(decoded.handNumber == 1)
        #expect(decoded.smallBlind == 1)
        #expect(decoded.bigBlind == 2)
        #expect(decoded.pot == 0)
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

        let encoded = try GamePayload.encodeToString(state)
        let decoded = try GamePayload.decode(fromString: encoded)

        #expect(decoded.players[0].stack == 0)
        #expect(decoded.players[0].bet == 0)
        #expect(decoded.players[0].committed == 0)
    }

    @Test("decoded players normalize profile text")
    func decodedPlayersNormalizeProfileText() throws {
        var state = sixPlayerState()
        state.players[0].name = "   "
        state.players[0].avatar = "   "
        state.players[1].name = "  \(String(repeating: "B", count: ProfileText.maxNameLength + 4))  "
        state.players[1].avatar = "  \(String(repeating: "B", count: ProfileText.maxAvatarLength + 4))  "

        let encoded = try GamePayload.encodeToString(state)
        let decoded = try GamePayload.decode(fromString: encoded)

        #expect(decoded.players[0].name == "Player")
        #expect(decoded.players[0].avatar == "🙂")
        #expect(decoded.players[1].name == String(repeating: "B", count: ProfileText.maxNameLength))
        #expect(decoded.players[1].avatar == String(repeating: "B", count: ProfileText.maxAvatarLength))
    }

    @Test("decoded players replace empty identities")
    func decodedPlayersReplaceEmptyIdentities() throws {
        var state = sixPlayerState()
        state.players[0].id = ""

        let encoded = try GamePayload.encodeToString(state)
        let decoded = try GamePayload.decode(fromString: encoded)

        #expect(!decoded.players[0].id.isEmpty)
    }

    @Test("decoded players replace duplicate identities")
    func decodedPlayersReplaceDuplicateIdentities() throws {
        var state = sixPlayerState()
        state.players[1].id = state.players[0].id

        let encoded = try GamePayload.encodeToString(state)
        let decoded = try GamePayload.decode(fromString: encoded)

        #expect(Set(decoded.players.map(\.id)).count == decoded.players.count)
        #expect(decoded.players[0].id == state.players[0].id)
    }

    @Test("decoded lobby seats normalize identity and profile text")
    func decodedLobbySeatsNormalizeIdentityAndProfileText() throws {
        var lobby = Lobby(seats: [
            LobbySeat(id: "a", name: "Alice", avatar: "A"),
        ])
        lobby.seats[0].id = ""
        lobby.seats[0].name = String(repeating: "L", count: ProfileText.maxNameLength + 4)
        lobby.seats[0].avatar = "   "

        let encoded = try GamePayload.encodeToString(TableMessage.lobby(lobby))
        guard case .lobby(let decoded) = try GamePayload.decodeMessage(fromString: encoded) else {
            Issue.record("expected lobby"); return
        }

        #expect(!decoded.seats[0].id.isEmpty)
        #expect(decoded.seats[0].name == String(repeating: "L", count: ProfileText.maxNameLength))
        #expect(decoded.seats[0].avatar == "🙂")
    }

    @Test("decoded game states normalize stored seat indexes")
    func decodedGameStateNormalizesStoredSeatIndexes() throws {
        var state = sixPlayerState()
        state.dealerIndex = -5
        state.currentToAct = 99

        let encoded = try GamePayload.encodeToString(state)
        let decoded = try GamePayload.decode(fromString: encoded)

        #expect(decoded.dealerIndex == 1)
        #expect(decoded.currentToAct == nil)
    }

    @Test("decoded live game states fold departed active players")
    func decodedLiveGameStatesFoldDepartedActivePlayers() throws {
        var state = sixPlayerState()
        state.results = nil
        state.players[0].hasLeft = true
        state.players[0].status = .active
        state.currentToAct = 0

        let encoded = try GamePayload.encodeToString(state)
        let decoded = try GamePayload.decode(fromString: encoded)

        #expect(decoded.players[0].status == .folded)
        #expect(!decoded.players[0].isContesting)
        #expect(decoded.currentToAct == nil)
    }

    @Test("decoded completed game states clear actor clocks")
    func decodedCompletedGameStatesClearActorClocks() throws {
        var state = sixPlayerState()
        state.street = .showdown
        state.currentToAct = 0
        state.turnStartedAt = Date()
        state.results = [
            HandResult(playerID: state.players[0].id, amountWon: 20,
                       handName: nil, bestFive: nil),
        ]

        let encoded = try GamePayload.encodeToString(state)
        let decoded = try GamePayload.decode(fromString: encoded)

        #expect(decoded.currentToAct == nil)
        #expect(decoded.turnStartedAt == nil)
    }

    @Test("decoded completed game states normalize to showdown")
    func decodedCompletedGameStatesNormalizeToShowdown() throws {
        var state = sixPlayerState()
        state.street = .turn
        state.results = [
            HandResult(playerID: state.players[0].id, amountWon: 20,
                       handName: "Pair", bestFive: nil),
        ]

        let encoded = try GamePayload.encodeToString(state)
        let decoded = try GamePayload.decode(fromString: encoded)

        #expect(decoded.street == .showdown)
    }

    @Test("decoded completed game states clear live betting state")
    func decodedCompletedGameStatesClearLiveBettingState() throws {
        var state = sixPlayerState()
        state.players[0].bet = 10
        state.players[0].hasActed = true
        state.pot = 50
        state.currentBet = 20
        state.results = [
            HandResult(playerID: state.players[0].id, amountWon: 80,
                       handName: nil, bestFive: nil),
        ]

        let encoded = try GamePayload.encodeToString(state)
        let decoded = try GamePayload.decode(fromString: encoded)

        #expect(decoded.pot == 0)
        #expect(decoded.currentBet == 0)
        #expect(decoded.players.allSatisfy { $0.bet == 0 })
        #expect(decoded.players.allSatisfy { !$0.hasActed })
    }

    @Test("decoded game states normalize holdem card shape")
    func decodedGameStatesNormalizeHoldemCardShape() throws {
        var state = sixPlayerState()
        for index in state.players.indices {
            state.players[index].holeCards = []
        }
        state.players[0].holeCards = cards("Ah Kh Qh")
        state.board = cards("2h 3h 4h 5h 6h 7h")

        let encoded = try GamePayload.encodeToString(state)
        let decoded = try GamePayload.decode(fromString: encoded)

        #expect(decoded.players[0].holeCards == cards("Ah Kh"))
        #expect(decoded.board == cards("2h 3h 4h 5h 6h"))
    }

    @Test("decoded hand results normalize non-negative winnings")
    func decodedHandResultsNormalizeNonNegativeWinnings() throws {
        var state = sixPlayerState()
        state.results = [
            HandResult(playerID: state.players[0].id, amountWon: -50,
                       handName: nil, bestFive: nil),
        ]

        let encoded = try GamePayload.encodeToString(state)
        let decoded = try GamePayload.decode(fromString: encoded)

        #expect(decoded.results?.first?.amountWon == 0)
    }

    @Test("decoded hand results are limited to current players")
    func decodedHandResultsAreLimitedToCurrentPlayers() throws {
        var state = sixPlayerState()
        state.results = [
            HandResult(playerID: "", amountWon: 30, handName: nil, bestFive: nil),
            HandResult(playerID: "missing", amountWon: 20, handName: nil, bestFive: nil),
            HandResult(playerID: state.players[1].id, amountWon: 10, handName: nil, bestFive: nil),
        ]

        let encoded = try GamePayload.encodeToString(state)
        let decoded = try GamePayload.decode(fromString: encoded)

        #expect(decoded.results?.map(\.playerID) == [state.players[1].id])
    }

    @Test("decoded hand results merge duplicate players")
    func decodedHandResultsMergeDuplicatePlayers() throws {
        var state = sixPlayerState()
        state.results = [
            HandResult(playerID: state.players[1].id, amountWon: 10, handName: "Pair", bestFive: nil),
            HandResult(playerID: state.players[0].id, amountWon: 5, handName: nil, bestFive: nil),
            HandResult(playerID: state.players[1].id, amountWon: 20, handName: "Flush", bestFive: nil),
        ]

        let encoded = try GamePayload.encodeToString(state)
        let decoded = try GamePayload.decode(fromString: encoded)

        #expect(decoded.results?.map(\.playerID) == [state.players[1].id, state.players[0].id])
        #expect(decoded.results?.map(\.amountWon) == [30, 5])
        #expect(decoded.results?.first?.handName == "Pair")
    }

    @Test("decoded hand results clear impossible best-five highlights")
    func decodedHandResultsClearImpossibleBestFiveHighlights() throws {
        var state = sixPlayerState()
        state.board = cards("2h 3h 4h 5h 6h")
        state.players[0].holeCards = cards("Ah Kh")
        state.players[1].holeCards = cards("Ac Kc")
        state.results = [
            HandResult(playerID: state.players[0].id,
                       amountWon: 20,
                       handName: "Flush",
                       bestFive: cards("Ah Kh 2h 3h 4h")),
            HandResult(playerID: state.players[1].id,
                       amountWon: 0,
                       handName: "Flush",
                       bestFive: cards("Ac Kc Qc Jc Tc")),
        ]

        let encoded = try GamePayload.encodeToString(state)
        let decoded = try GamePayload.decode(fromString: encoded)

        #expect(decoded.results?.first?.bestFive == cards("Ah Kh 2h 3h 4h"))
        #expect(decoded.results?.dropFirst().first?.bestFive == nil)
    }

    @Test("decoded operation history is ordered and unique")
    func decodedOperationHistoryIsOrderedAndUnique() throws {
        var state = sixPlayerState()
        state.appliedOperationIDs = ["op-1", "", "op-2", "op-1", "op-3", "", "op-2"]

        let encoded = try GamePayload.encodeToString(state)
        let decoded = try GamePayload.decode(fromString: encoded)

        #expect(decoded.appliedOperationIDs == ["op-1", "op-2", "op-3"])
    }

    @Test("decoded game states replace empty table identities")
    func decodedGameStatesReplaceEmptyTableIdentities() throws {
        var state = sixPlayerState()
        state.tableID = ""

        let encoded = try GamePayload.encodeToString(state)
        let decoded = try GamePayload.decode(fromString: encoded)

        #expect(!decoded.tableID.isEmpty)
    }
}
