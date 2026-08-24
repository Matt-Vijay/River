import Foundation
import Testing

@testable import GameCore

@Suite("Table mutation receipts")
struct TableMutationReceiptTests {
    @Test("every operation preserves its exact associated inputs")
    func operationCodableRoundTrips() throws {
        let operations: [TableOperation] = [
            .joinLobby(name: " Alice \n", avatar: "🃏"),
            .startGame(seed: UInt64.max, turnDuration: 29.125),
            .leaveLobby,
            .gameAction(.fold),
            .gameAction(.check),
            .gameAction(.call),
            .gameAction(.raise(to: Int.max)),
            .resolveTimeout,
            .joinGame(name: "Bob", avatar: " B ", startingStack: Int.min),
            .leaveGame,
            .dealNextHand(seed: UInt64.max),
        ]

        var largest = 0
        for operation in operations {
            let data = try GamePayload.encoder.encode(operation)
            largest = max(largest, data.count)
            #expect(try GamePayload.decoder.decode(TableOperation.self, from: data) == operation)
        }
        #expect(largest < 128)
    }

    @Test("the first legacy-lobby join records, round-trips, and replays")
    func firstLobbyJoinAndLegacyCompatibility() throws {
        let legacyJSON = #"{"lobby":{"_0":{"bigBlind":10,"maxPlayers":6,"seats":[],"smallBlind":5,"startingStack":1000}}}"#
        let legacyWire = Data(legacyJSON.utf8).base64URLEncodedString()
        let predecessor = try GamePayload.decodeMessage(from: legacyWire)
        let actor = try #require(TableActor("alice"))
        let exactTime = Date(timeIntervalSinceReferenceDate: 789_123_456.123_456_7)

        guard case .applied(let result, let receipt) = TableMutationReceipt.recording(
            .joinLobby(name: "Alice", avatar: "🃏"),
            on: predecessor,
            actor: actor,
            at: exactTime
        ) else {
            Issue.record("expected first lobby join to be recorded")
            return
        }
        guard case .lobby(let joined) = result else {
            Issue.record("expected lobby result")
            return
        }

        let encoded = try receipt.encoded()
        let decoded = try TableMutationReceipt.decode(from: encoded)
        #expect(joined.seats.map(\.id) == ["alice"])
        #expect(decoded == receipt)
        #expect(decoded.actorID == "alice")
        #expect(decoded.operation == .joinLobby(name: "Alice", avatar: "🃏"))
        #expect(decoded.appliedAt.timeIntervalSinceReferenceDate.bitPattern
                == exactTime.timeIntervalSinceReferenceDate.bitPattern)
        #expect(decoded.parentRevision == predecessor.revision)
        #expect(decoded.resultRevision == result.revision)
        #expect(decoded.parentFingerprint.count == 32)
        #expect(decoded.resultFingerprint.count == 32)
        #expect(decoded.parentFingerprint != decoded.resultFingerprint)
        #expect(decoded.matchesResult(result))
        #expect(!decoded.matchesResult(predecessor))
        #expect(decoded.verifying(predecessor: predecessor, authenticatedActor: actor)
                == .verified(result))
        #expect(encoded.count == 515)

        // The receipt is separate: both frozen legacy input and ordinary state
        // payloads retain their existing codecs and transport budget.
        #expect(try GamePayload.decodeMessage(from: legacyWire) == predecessor)
        let stateWire = try GamePayload.encode(result)
        #expect(stateWire.utf8.count < GamePayload.maximumEncodedPayloadLength)
        #expect(try GamePayload.decodeMessage(from: stateWire) == result)
    }

    @Test("phase-changing and game operations replay deterministically")
    func phaseAndGameReplay() throws {
        let lobby = TableMessage.lobby(
            Lobby(tableID: "replay-table")
                .fixtureSeat(id: "a", name: "Alice", avatar: "A")
                .fixtureSeat(id: "b", name: "Bob", avatar: "B")
        )
        let host = try #require(TableActor("a"))
        let dealTime = Date(timeIntervalSinceReferenceDate: 700_000_000.000_000_1)
        guard case .applied(let game, let startReceipt) = TableMutationReceipt.recording(
            .startGame(seed: 0xCAFE_BABE, turnDuration: 29.75),
            on: lobby,
            actor: host,
            at: dealTime
        ) else {
            Issue.record("expected start-game receipt")
            return
        }
        let decodedStart = try TableMutationReceipt.decode(from: startReceipt.encoded())
        #expect(decodedStart.parentRevision.phase == .lobby)
        #expect(decodedStart.resultRevision.phase == .game)
        #expect(decodedStart.verifying(predecessor: lobby, authenticatedActor: host)
                == .verified(game))

        guard case .game(let state) = game,
              let actorIndex = state.currentToAct,
              let actor = TableActor(state.players[actorIndex].id) else {
            Issue.record("expected current game actor")
            return
        }
        let actionTime = Date(timeIntervalSinceReferenceDate: 700_000_001.25)
        guard case .applied(let acted, let actionReceipt) = TableMutationReceipt.recording(
            .gameAction(.fold), on: game, actor: actor, at: actionTime
        ) else {
            Issue.record("expected game-action receipt")
            return
        }
        let decodedAction = try TableMutationReceipt.decode(from: actionReceipt.encoded())
        #expect(decodedAction.verifying(predecessor: game, authenticatedActor: actor)
                == .verified(acted))
    }

    @Test("replay rejects wrong actor, table, parent, operation outcome, and result")
    func replayRejectionMatrix() throws {
        let predecessor = TableMessage.lobby(Lobby(tableID: "receipt-table"))
        let alice = try #require(TableActor("alice"))
        let bob = try #require(TableActor("bob"))
        let now = Date(timeIntervalSinceReferenceDate: 700_000_000)
        let aliceOperation = TableOperation.joinLobby(name: "Alice", avatar: "A")
        guard case .applied(let aliceJoined, let receipt) = TableMutationReceipt.recording(
            aliceOperation, on: predecessor, actor: alice, at: now
        ), case .applied(let bobJoined) = predecessor.committing(
            .joinLobby(name: "Bob", avatar: "B"), actor: bob, now: now
        ) else {
            Issue.record("expected concurrent lobby successors")
            return
        }

        #expect(receipt.verifying(predecessor: predecessor, authenticatedActor: bob)
                == .rejected(.wrongActor))
        #expect(receipt.verifying(
            predecessor: .lobby(Lobby(tableID: "other-table")), authenticatedActor: alice
        ) == .rejected(.wrongTable))
        #expect(receipt.verifying(predecessor: bobJoined, authenticatedActor: alice)
                == .rejected(.wrongParent))

        let falseResult = try #require(TableMutationReceipt(
            actor: alice,
            parent: predecessor,
            operation: aliceOperation,
            appliedAt: now,
            claimedResult: bobJoined
        ))
        #expect(falseResult.verifying(predecessor: predecessor, authenticatedActor: alice)
                == .rejected(.wrongResult))

        let rejectedOperation = try #require(TableMutationReceipt(
            actor: alice,
            parent: predecessor,
            operation: .leaveLobby,
            appliedAt: now,
            claimedResult: aliceJoined
        ))
        #expect(rejectedOperation.verifying(
            predecessor: predecessor, authenticatedActor: alice
        ) == .rejected(.operationRejected(.notSeated)))

        guard case .applied(let secondJoin) = aliceJoined.committing(
            .joinLobby(name: "Bob", avatar: "B"), actor: bob, now: now
        ) else {
            Issue.record("expected second join")
            return
        }
        let unchangedOperation = try #require(TableMutationReceipt(
            actor: alice,
            parent: aliceJoined,
            operation: aliceOperation,
            appliedAt: now,
            claimedResult: secondJoin
        ))
        #expect(unchangedOperation.verifying(
            predecessor: aliceJoined, authenticatedActor: alice
        ) == .rejected(.operationUnchanged))
    }

    @Test("all protected fields, noncanonical bytes, and oversized inputs are rejected")
    func tamperAndPayloadLimits() throws {
        let predecessor = TableMessage.lobby(Lobby(tableID: "tamper-table"))
        let actor = try #require(TableActor("alice"))
        guard case .applied(_, let receipt) = TableMutationReceipt.recording(
            .joinLobby(name: "Alice", avatar: "A"),
            on: predecessor,
            actor: actor,
            at: Date(timeIntervalSinceReferenceDate: 700_000_000)
        ) else {
            Issue.record("expected receipt")
            return
        }
        let encoded = try receipt.encoded()
        let original = try #require(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )

        let mutations: [(String, (inout [String: Any]) throws -> Void)] = [
            ("actor", { object in try mutateBody(&object) { $0["a"] = "mallory" } }),
            ("operation", { object in
                let replacement = try JSONSerialization.jsonObject(
                    with: GamePayload.encoder.encode(TableOperation.leaveLobby))
                try mutateBody(&object) { $0["o"] = replacement }
            }),
            ("time", { object in try mutateBody(&object) { $0["t"] = 0 } }),
            ("parent", { object in try mutateReference("p", in: &object) }),
            ("result", { object in try mutateReference("r", in: &object) }),
            ("integrity", { object in object["h"] = String(repeating: "0", count: 64) }),
            ("version", { object in try mutateBody(&object) { $0["v"] = 2 } }),
            ("unknown", { object in object["x"] = true }),
        ]

        for (label, mutate) in mutations {
            var object = original
            try mutate(&object)
            let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
            do {
                _ = try TableMutationReceipt.decode(from: data)
                Issue.record("accepted tampered \(label) field")
            } catch {
                // Every mutation must fail either semantic/integrity validation
                // or canonical-byte validation.
            }
        }

        do {
            _ = try TableMutationReceipt.decode(from: encoded + Data([0x20]))
            Issue.record("accepted noncanonical trailing whitespace")
        } catch {}
        #expect(throws: TableMutationReceipt.CodingFailure.self) {
            _ = try TableMutationReceipt.decode(from: Data())
        }
        #expect(throws: TableMutationReceipt.CodingFailure.self) {
            _ = try TableMutationReceipt.decode(
                from: Data(repeating: 65, count: TableMutationReceipt.maximumEncodedLength + 1))
        }
        #expect(TableMutationReceipt.recording(
            .joinLobby(name: String(repeating: "A", count: 2_000), avatar: "A"),
            on: predecessor,
            actor: actor
        ) == .unrecordable)
        #expect(TableMutationReceipt.recording(
            .joinLobby(name: "Alice", avatar: "A"),
            on: predecessor,
            actor: actor,
            at: Date(timeIntervalSinceReferenceDate: .infinity)
        ) == .unrecordable)
    }
}

private func mutateBody(
    _ object: inout [String: Any],
    mutation: (inout [String: Any]) throws -> Void
) throws {
    var body = try #require(object["b"] as? [String: Any])
    try mutation(&body)
    object["b"] = body
}

private func mutateReference(_ key: String, in object: inout [String: Any]) throws {
    try mutateBody(&object) { body in
        var reference = try #require(body[key] as? [String: Any])
        reference["f"] = String(repeating: "0", count: 32)
        body[key] = reference
    }
}
