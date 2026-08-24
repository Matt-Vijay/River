import Compression
import Foundation
import Testing
@testable import GameCore

@Suite("Adversarial payload verification")
struct PayloadAdversarialTests {
    private struct OutcomeCase {
        let name: String
        let wire: String
        let failure: GamePayload.DecodeFailure
    }

    @Test("canonical base64url is accepted and noncanonical transports are rejected")
    func canonicalBase64URLOnly() throws {
        let message = TableMessage.lobby(Lobby(tableID: "transport-table"))
        let raw = try GamePayload.encoder.encode(message)
        let canonicalRaw = raw.base64URLEncodedString()
        let canonicalCompressed = try GamePayload.encode(message)

        #expect(GamePayload.decodeOutcome(from: canonicalRaw) == .decoded(message))
        #expect(GamePayload.decodeOutcome(from: canonicalCompressed) == .decoded(message))
        #expect(!canonicalRaw.contains("="))
        #expect(!canonicalCompressed.contains(where: { "+/=".contains($0) }))

        let rejected = [
            canonicalRaw + "=", // padding is valid base64, but not canonical base64url
            "+w",               // standard base64 alphabet
            "%2Fw",             // percent-encoded transport text
            "A",                // impossible base64 length
            "AA==",             // explicit padding
            "AA\n",             // ignored by some permissive base64 decoders
            "é",                 // non-ASCII transport byte
            "z",                // compressed marker without a body
        ]
        for wire in rejected {
            #expect(
                GamePayload.decodeOutcome(from: wire) == .rejected(.malformedEncoding),
                "unexpected classification for \(String(reflecting: wire))"
            )
        }
    }

    @Test("empty, truncated, and over-expanding LZFSE inputs fail closed")
    func boundedLZFSEDecoding() throws {
        let validJSON = Data(#"{"wireVersion":1,"lobby":{"_0":{"tableID":"t","version":0,"seats":[],"maxPlayers":6,"smallBlind":5,"bigBlind":10,"startingStack":1000}}}"#.utf8)
        let compressed = try (validJSON as NSData).compressed(using: .lzfse) as Data
        #expect(compressed.count > 4)

        let malformed = [
            ("invalid bytes", "zAA"),
            ("empty stream", try compressedWire(Data())),
            ("one-byte prefix", try compressedWire(Data(compressed.prefix(1)))),
            ("half stream", try compressedWire(Data(compressed.prefix(compressed.count / 2)))),
            ("missing trailer", try compressedWire(Data(compressed.dropLast()))),
        ]
        for (name, wire) in malformed {
            let outcome = GamePayload.decodeOutcome(from: wire)
            let failedClosed = switch outcome {
            case .rejected(.invalidCompression), .rejected(.invalidShape): true
            default: false
            }
            #expect(failedClosed, "truncated LZFSE did not fail closed: \(name)")
            #expect(GamePayload.decodeOutcome(from: wire) == outcome)
        }

        let atCeiling = Data(repeating: 0x20, count: GamePayload.maximumDecodedPayloadLength)
        let overCeiling = Data(
            repeating: 0x20, count: GamePayload.maximumDecodedPayloadLength + 1)
        #expect(GamePayload.decodeOutcome(from: try compressedWire(atCeiling))
            == .rejected(.invalidShape))
        #expect(GamePayload.decodeOutcome(from: try compressedWire(overCeiling))
            == .rejected(.decodedTooLarge))
    }

    @Test("generated JSON inputs enforce every structural budget")
    func generatedJSONShapeBudgets() throws {
        let nested = String(repeating: #"{"a":"#, count: 13)
            + "0" + String(repeating: "}", count: 13)
        let wideNodes = [String](
            repeating: "[" + [String](repeating: "0", count: 64).joined(separator: ",") + "]",
            count: 8
        ).joined(separator: ",")
        let tooManyKeys = (0..<33).map { #""k\#($0)":0"# }.joined(separator: ",")

        let rejectedJSON = [
            "[]",                                                   // object root required
            "null",                                                 // scalar root required
            nested,                                                  // depth 13 > 12
            #"{"a":["# + wideNodes + "]}",                    // 522 nodes > 512
            #"{"a":["# + [String](repeating: "0", count: 65)
                .joined(separator: ",") + "]}",                    // array 65 > 64
            "{" + tooManyKeys + "}",                              // object fields 33 > 32
            #"{"":0}"#,                                           // empty key
            #"{""# + String(repeating: "k", count: 65) + #"":0}"#,
            #"{"a":""# + String(repeating: "s", count: 4_097) + #""}"#,
            #"{"unterminated":true"#,                             // malformed JSON
        ]
        for json in rejectedJSON {
            #expect(GamePayload.decodeOutcome(from: try compressedWire(Data(json.utf8)))
                == .rejected(.invalidShape))
        }
    }

    @Test("duplicate and unknown envelope fields are rejected before state decoding")
    func strictEnvelopeKeys() throws {
        let state = #"{"tableID":"duplicate-table","version":0,"seats":[],"maxPlayers":6,"smallBlind":5,"bigBlind":10,"startingStack":1000}"#
        let duplicateEnvelopes = [
            #"{"wireVersion":1,"wireVersion":1,"lobby":{"_0":"#
                + state + "}}",
            #"{"wireVersion":1,"wire\u0056ersion":1,"lobby":{"_0":"#
                + state + "}}",
            #"{"wireVersion":1,"lobby":{"_0":{"tableID":"nested","table\u0049D":"nested","version":0,"seats":[],"maxPlayers":6,"smallBlind":5,"bigBlind":10,"startingStack":1000}}}"#,
        ]

        var unknown = try envelopeObject(for: .lobby(Lobby(tableID: "unknown-table")))
        unknown["unexpected"] = true

        for duplicate in duplicateEnvelopes {
            #expect(GamePayload.decodeOutcome(from: try compressedWire(Data(duplicate.utf8)))
                == .rejected(.invalidShape))
        }
        #expect(GamePayload.decodeOutcome(from: try objectWire(unknown))
            == .rejected(.invalidShape))
    }

    @Test("control and oversized wire identities never normalize into authority")
    func hostileWireIdentities() throws {
        let base = Lobby(tableID: "identity-table")
            .fixtureSeat(id: "player-a", name: "Alice", avatar: "A")
        let invalidIdentities = [
            "table\u{0}control",
            String(repeating: "i", count: Identity.maximumUTF8Length + 1),
        ]

        for identity in invalidIdentities {
            var tableObject = try legacyEnvelopeObject(for: .lobby(base))
            try mutateLobby(in: &tableObject) { $0["tableID"] = identity }
            #expect(GamePayload.decodeOutcome(from: try objectWire(tableObject))
                == .rejected(.invalidState))

            var seatObject = try legacyEnvelopeObject(for: .lobby(base))
            try mutateLobby(in: &seatObject) { lobby in
                var seats = try #require(lobby["seats"] as? [[String: Any]])
                seats[0]["id"] = identity
                lobby["seats"] = seats
            }
            #expect(GamePayload.decodeOutcome(from: try objectWire(seatObject))
                == .rejected(.invalidState))
        }
    }

    @Test("persisted revisions reject invalid counters, phases, and branch digests")
    func invalidRevisionPersistence() throws {
        let invalidRevisions: [[String: Any]] = [
            ["tableID": "t", "phase": 0, "version": -1, "branch": ""],
            ["tableID": "t", "phase": 2, "version": 0, "branch": ""],
            ["tableID": "t", "phase": 0, "version": 0,
             "branch": String(repeating: "0", count: 31)],
            ["tableID": "t", "phase": 0, "version": 0,
             "branch": String(repeating: "0", count: 33)],
            ["tableID": "t", "phase": 0, "version": 0,
             "branch": String(repeating: "A", count: 32)],
            ["tableID": "t", "phase": 0, "version": 0,
             "branch": String(repeating: "g", count: 32)],
        ]

        for object in invalidRevisions {
            let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
            #expect(throws: DecodingError.self) {
                _ = try JSONDecoder().decode(TableRevision.self, from: data)
            }
        }
    }

    @Test("DecodeFailure classification is stable across all rejection families")
    func deterministicFailureClassification() throws {
        var future = try envelopeObject(for: .lobby(Lobby(tableID: "future-table")))
        future["wireVersion"] = 3

        var corruptIntegrity = try envelopeObject(
            for: .lobby(Lobby(tableID: "integrity-table")))
        corruptIntegrity["integrity"] = String(repeating: "0", count: 64)

        var invalidState = try legacyEnvelopeObject(
            for: .lobby(Lobby(tableID: "state-table")))
        try mutateLobby(in: &invalidState) { $0["maxPlayers"] = 99 }

        let cases = [
            OutcomeCase(name: "empty", wire: "", failure: .empty),
            OutcomeCase(
                name: "transport", wire: String(
                    repeating: "A", count: GamePayload.maximumEncodedPayloadLength + 1),
                failure: .transportTooLarge),
            OutcomeCase(name: "encoding", wire: "AA==", failure: .malformedEncoding),
            OutcomeCase(name: "compression", wire: "zAA", failure: .invalidCompression),
            OutcomeCase(
                name: "expansion",
                wire: try compressedWire(Data(
                    repeating: 0x41, count: GamePayload.maximumDecodedPayloadLength + 1)),
                failure: .decodedTooLarge),
            OutcomeCase(
                name: "shape", wire: try compressedWire(Data("[]".utf8)),
                failure: .invalidShape),
            OutcomeCase(
                name: "version", wire: try objectWire(future),
                failure: .unsupportedVersion),
            OutcomeCase(
                name: "integrity", wire: try objectWire(corruptIntegrity),
                failure: .integrityMismatch),
            OutcomeCase(
                name: "state", wire: try objectWire(invalidState),
                failure: .invalidState),
        ]

        for testCase in cases {
            let expected = GamePayload.DecodeOutcome.rejected(testCase.failure)
            for _ in 0..<3 {
                #expect(
                    GamePayload.decodeOutcome(from: testCase.wire) == expected,
                    "unstable DecodeFailure for \(testCase.name)"
                )
            }
        }
    }

    private func envelopeObject(for message: TableMessage) throws -> [String: Any] {
        try #require(
            JSONSerialization.jsonObject(with: GamePayload.encoder.encode(message))
                as? [String: Any]
        )
    }

    private func legacyEnvelopeObject(for message: TableMessage) throws -> [String: Any] {
        var object = try envelopeObject(for: message)
        object["wireVersion"] = 1
        object.removeValue(forKey: "integrity")
        return object
    }

    private func mutateLobby(
        in object: inout [String: Any],
        _ mutation: (inout [String: Any]) throws -> Void
    ) throws {
        var wrapper = try #require(object["lobby"] as? [String: Any])
        var lobby = try #require(wrapper["_0"] as? [String: Any])
        try mutation(&lobby)
        wrapper["_0"] = lobby
        object["lobby"] = wrapper
    }

    private func objectWire(_ object: [String: Any]) throws -> String {
        try compressedWire(JSONSerialization.data(
            withJSONObject: object, options: [.sortedKeys]))
    }

    private func compressedWire(_ data: Data) throws -> String {
        let compressed = try (data as NSData).compressed(using: .lzfse) as Data
        return "z" + compressed.base64URLEncodedString()
    }
}
