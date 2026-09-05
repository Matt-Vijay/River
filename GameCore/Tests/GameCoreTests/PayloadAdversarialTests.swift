import Compression
import Foundation
import Testing
@testable import GameCore

@Suite("Adversarial payload verification")
struct PayloadAdversarialTests {
    @Test("canonical base64url is accepted and noncanonical transports are rejected")
    func canonicalBase64URLOnly() throws {
        let message = TableMessage.lobby(Lobby(tableID: "transport-table"))
        let raw = try GamePayload.encoder.encode(message)
        let canonicalRaw = raw.base64URLEncodedString()
        let canonicalCompressed = try GamePayload.encode(message)

        #expect(try GamePayload.decodeMessage(from: canonicalRaw) == message)
        #expect(try GamePayload.decodeMessage(from: canonicalCompressed) == message)
        #expect(!canonicalRaw.contains("="))
        #expect(!canonicalCompressed.contains(where: { "+/=".contains($0) }))

        let rejected = [
            "",                 // empty transport
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
            expectInvalidPayload(wire)
        }
    }

    @Test("empty, truncated, and over-expanding LZFSE inputs fail closed")
    func boundedLZFSEDecoding() throws {
        let validJSON = Data(#"{"wireVersion":1,"lobby":{"_0":{"tableID":"t","version":0,"seats":[],"maxPlayers":6,"smallBlind":5,"bigBlind":10,"startingStack":1000}}}"#.utf8)
        let compressed = try (validJSON as NSData).compressed(using: .lzfse) as Data
        #expect(compressed.count > 4)

        let malformed = [
            "zAA",
            try compressedWire(Data()),
            "z" + compressed.prefix(1).base64URLEncodedString(),
            "z" + compressed.prefix(compressed.count / 2).base64URLEncodedString(),
            "z" + compressed.dropLast().base64URLEncodedString(),
        ]
        for wire in malformed {
            expectInvalidPayload(wire)
        }

        let atCeiling = Data(repeating: 0x20, count: GamePayload.maximumDecodedPayloadLength)
        let overCeiling = Data(
            repeating: 0x20, count: GamePayload.maximumDecodedPayloadLength + 1)
        expectInvalidPayload(try compressedWire(atCeiling))
        expectInvalidPayload(try compressedWire(overCeiling))
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
            expectInvalidPayload(try compressedWire(Data(json.utf8)))
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
            expectInvalidPayload(try compressedWire(Data(duplicate.utf8)))
        }
        expectInvalidPayload(try objectWire(unknown))
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
            expectInvalidPayload(try objectWire(tableObject))

            var seatObject = try legacyEnvelopeObject(for: .lobby(base))
            try mutateLobby(in: &seatObject) { lobby in
                var seats = try #require(lobby["seats"] as? [[String: Any]])
                seats[0]["id"] = identity
                lobby["seats"] = seats
            }
            expectInvalidPayload(try objectWire(seatObject))
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
