import Compression
import CryptoKit
import Foundation
import Testing

@testable import GameCore

@Suite("Frozen legacy wire corpus")
struct LegacyWireCorpusTests {
    private enum FixtureID: String, Sendable {
        case implicitV0Lobby
        case v1Lobby
        case v0HeadsUpOldMarkers
        case v1LiveMultiway
        case v1UnmatchedBlind
        case v1AlternateBestFive
    }

    private struct Fixture: Sendable {
        let id: FixtureID
        let wireVersion: Int?
        let tableID: String
        let revision: Int
        let sha256: String
        let wire: String
    }

    private static let fixtures: [Fixture] = [
        Fixture(
            id: .implicitV0Lobby, wireVersion: nil,
            tableID: "legacy-v1-feb2817a4b974e17e643abea2b604712", revision: 0,
            sha256: "272db8835a18f3de53309311bcbcef5f250c7f9998d92c35999a63883e8e75ce",
            wire: "zYnZ4bq4AAACYAAAA7XsibG9iYnkiOnsiXzAIBuARYmlnQmxpbmQiOjEwLCJtYXhQbGF5ZXJzIjo0LCJzZWF0AArgAVt7ImF2YXRhciI6IkEiLCJpAC7mImFsaWNlAA3kbmFtZQgYEA-YK30s9W5CyClib2L2QA1CgFx9XeRtYWxsIHtADzXgBHRhcnRpbmdTdGFjayI6NTAwfX19BgAAAAAAAABidngk"
        ),
        Fixture(
            id: .v1Lobby, wireVersion: 1,
            tableID: "corpus-lobby-v1", revision: 4,
            sha256: "46592b1a281d8ff1d6ff15c96c579e478c2c6e97a34daeefc199c42e87b98215",
            wire: "zYnZ4brwAAACzAAAA7XsibG9iYnkiOnsiXzAIBuARYmlnQmxpbmQiOjIwLCJtYXhQbGF5ZXJzIjo2LCJzZWF0AArgAVt7ImF2YXRhciI6IlAiLCJpAC7ACiJwMORuYW1lCBXlYXQifV0AMORtYWxsIE9GMUA0c-l0aW5nU3RhY2sAE4AVNTDndGFibGVJRAA352NvcnB1cy0QksBQLXYxQHp272lvbiI6NH19LCJ3aXJlVigS4jF9BgAAAAAAAABidngk"
        ),
        Fixture(
            id: .v0HeadsUpOldMarkers, wireVersion: 0,
            tableID: "corpus-hu-v0", revision: 1,
            sha256: "db9cd5850829b3f1b4ddb163b72a6ab718046c1bd56df73f4552872b73cd6402",
            wire: "zYnZ4bskCAAAFAgAA7HsiZ2FtZSI6eyJfMAgG4AJiaWdCbGluZCI6MjAsImJvYXIAC-ATW10sImN1cnJlbnRUb0FjdCI6MSwiZGVhbGVySW5kZXgiOjAIEIArY2vgJDExLDMwLDEwLDQyLDIyLDUwLDAsMjEsNDgsOSwxMywyNCwzNywxMiw3LDQ1LDI1LDQ2LDQAFOg2LDE4LDEsMQAcgBM5LOU5LDgsMwAegAUzLICNMSzkMzksMwApgAssNOY4LDI4LDUAagAawDU5LDTnNSwzMiw0LAB05DYsMjMAsOpoYW5kTnVtYmVyAMvqLCJtaW5SYWlzZRjY53BsYXllcnMAr-d7ImF2YXRhACXmIvCfmYIiAPSYJWV06GNvbW1pdHRlIQzlaGFzQWMQDuR0cnVlEBDALExlZuRmYWxzCBDkb2xlQwEvCFZAijFAhTdALmnAViJwMORsYXN0AD_JZmlvbuRjYWxsAAjlfX0sIm4Rf4glIlDJRHN0YcgMOTgw8YBMdHWANiJh5XZlIn0sOKvwGiicOKzwAuQ2LDMz-ZiTMSL0bjHwCAA2yf5wb3TxgNNzbSI6UCwxyBtyZWXy53RhYmxlSUQAOOtjb3JwdXMtaHUtdgjv6HR1cm5EdXJhGRZIKzMAEkDjUwC8SmZBmAE3MPTBsywidhArSTkx5XdpcmVWKBLiMH0GAAAAAAAAAGJ2eCQ"
        ),
        Fixture(
            id: .v1LiveMultiway, wireVersion: 1,
            tableID: "corpus-multi-v1", revision: 1,
            sha256: "49e12e8133e7fb38f83636092e7fe762bca1b5fb6d9ab7fa51ace58ddfc433b7",
            wire: "zYnZ4bmkDAAAkAgAA7HsiZ2FtZSI6eyJfMAgG4AJiaWdCbGluZCI6MTAsImJvYXIAC-AQW10sImN1cnJlbnRUb0FjdCI6MiwiZGVhbGVySW5kZXgALQgQgCtja-AYNDYsMTUsMzAsMjIsMzMsMzgsMyw0NCw4LDUwLDM1LDE2LDIxLDksNAADwCEyLDLmNyw0LDAsABqAczQs5zIwLDQxLDQAGMASNiwz6DgsMTEsMTksADfoNCwzMiwxLDUAEO4yLDQ1LDcsMTcsMjUsMgBjwHg5LDLkMywyNwCr4AdoYW5kTnVtYmVyIjo3LCJtaW5SYWlzZRjT53BsYXllcnMAqud7ImF2YXRhACXmIvCfmYIiAO-YJWV06GNvbW1pdHRlIQflaGFzQWMQDuVmYWxzZRAR5ExlZnQ4EORvbGVDASsIV0C_M0CGMEAvacBXInAwUWJuiAwiUMknc3RhyAw5OTDxgDN0deoiYWN0aXZlIn0sOJPwGsiSdHJ18AsBaGiROfFGMeRsYXN0AD7J82lvbuRjYWxsAAiYGX199mh4Qii9bjHybjbwFWi8NfVouzX0OU7wCUIfNGlOOPFuMvNuMvJCDjM4kfgANoBWcG8IrUDkbSLYECvIGnJlZfLndGFibGVJRAA37mNvcnB1cy1tdWx0aS12CO_odHVybkR1cmEZKUguMwASQONTAL5JIEGYATcw9MJYLCJ2ECtJTDHld2lyZVYwEuF9BgAAAAAAAABidngk"
        ),
        Fixture(
            id: .v1UnmatchedBlind, wireVersion: 1,
            tableID: "corpus-unmatched-v1", revision: 1,
            sha256: "7806935664863cbbd086275eb7ec8a0317599f452ec597b15626c29ed21bcfd2",
            wire: "zYnZ4bs0CAAALAgAA7HsiZ2FtZSI6eyJfMAgG4AJiaWdCbGluZCI6MjAsImJvYXIAC-ACW10sImRlYWxlckluZGV4IjowCBCAGmNr4BYyNSwxNiwyNywyMSwxMywyNiwxNCw1MCw0OCw0Niw4LDM1LDIsMgAI4BI5LDQzLDQxLDI0LDMyLDE1LDQ5LDExLDYsMzcsNywzOCw1ABwAGcArOCwy6DQsNDUsOSwzAEnnMCwwLDUsMwBlwBMzLDEAQAAJADPnLDQyLDQsMQA0QKAw4AdoYW5kTnVtYmVyIjoxLCJtaW5SYWlzZRCs53BsYXllcnMAr-d7ImF2YXRhACTmIvCfmYIiAOOQJGV06GNvbW1pdHRlAO-ITzEwyA5zQWPx5WZhbHNlEBHkTGVmdDgQ5G9sZUMBHghW5DEsMzEAg0AuacBVInAw5Gxhc3QAP8lUaW9uwBpmb2zme319LCJuEW2IJSJQyUNzdGHIDDk5MPGAS3R1ECwAdpiqfSzwD24y8BgAMZirNDfzmJIxIvRuMfLIkzEwMfhAyWHkdmUifQA3mINwb-ZyZXN1bHQhUeZtb3VudFcI6wGvIWyYYElECDXlc21hbGwiVRhZiMtyZeg0LCJ0YWJsZRAs4AJjb3JwdXMtdW5tYXRjaGVkLXYIkeh0dXJuRHVyYRlKCF9ByHYQDUlPMeV3aXJlVjAS4X0GAAAAAAAAAGJ2eCQ"
        ),
        Fixture(
            id: .v1AlternateBestFive, wireVersion: 1,
            tableID: "corpus-alternate-v1", revision: 0,
            sha256: "3a0e66959d6c5253e86ae71d4b922cb9d90dad6be4b3097662009147b19aff0b",
            wire: "zYnZ4bu4CAAAYAgAA7HsiZ2FtZSI6eyJfMAgG4AJiaWdCbGluZCI6MjAsImJvYXIAC-APWzQ5LDQ4LDQ2LDQ1LDNdLCJkZWFsZXJJbmRleCI6MAgQgCdja-ADMCwxLDIsNCw1LDYsNyw4LDksMQAT4AoxLDEyLDEzLDE0LDE1LDE2LDE3LDE4LDE5LABjQDIy4BcyLDIzLDI0LDI1LDI2LDI3LDI4LDI5LDMwLDMxLDMyLDMzLDM0LDMAe-k2LDM3LDM4LDMAkMBsMSw05DMsNDcAkeAHaGFuZE51bWJlciI6OCwibWluUmFpc2UQnedwbGF5ZXJzAKDneyJhdmF0YQAk5iLwn5mCIgDhkCRldOhjb21taXR0ZQDtyFAxMDDID3NBY_HlZmFsc2UQEeRMZWZ0OBDkb2xlQwEdCFflNTAsNTEAhUAvacBXInAwUVRuiAwiUMkdc3RhUFgxAA2ANHR16iJhY3RpdmUifSw4lPA95TQ0LDQw-W4x824x8miTOf0ANpiDcG_mcmVzdWx0ITvobW91bnRXb24KG0inMMgxc3RGAQGBBDEsIiVpjzUYcOtGb3VyIG9mIGEgSwpXKY-ZLElECG7lc21hbGwidlCSMYkEcmXoNCwidGFibGUQLOACY29ycHVzLWFsdGVybmF0ZS12CMnqdHVybkR1cmF0aQiYAjKB6yJ2EA3qMH19LCJ3aXJlVigS4jF9BgAAAAAAAABidngk"
        ),
    ]

    @Test("literal v0/v1 wires decode deterministically and canonicalize to v2")
    func frozenCorpusCanonicalizes() throws {
        for fixture in Self.fixtures {
            #expect(hash(fixture.wire) == fixture.sha256, "fixture changed: \(fixture.id.rawValue)")
            #expect(fixture.wire.utf8.count <= GamePayload.maximumEncodedPayloadLength)

            let legacyData = try decodedWire(fixture.wire)
            #expect(legacyData.count <= GamePayload.maximumDecodedPayloadLength)
            let legacyRoot = try object(from: legacyData)
            #expect((legacyRoot["wireVersion"] as? Int) == fixture.wireVersion)

            let first = try GamePayload.decodeMessage(from: fixture.wire)
            let second = try GamePayload.decodeMessage(from: fixture.wire)
            #expect(first == second)
            #expect(first.revision == second.revision)
            #expect(first.revision.tableID == fixture.tableID)
            #expect(first.revision.version == fixture.revision)
            #expect(GamePayload.decodeOutcome(from: fixture.wire) == .decoded(first))

            let currentWire = try GamePayload.encode(first)
            #expect(currentWire.utf8.count <= GamePayload.maximumEncodedPayloadLength)
            let currentData = try decodedWire(currentWire)
            #expect(currentData.count <= GamePayload.maximumDecodedPayloadLength)
            let currentRoot = try object(from: currentData)
            #expect(currentRoot["wireVersion"] as? Int == 2)
            #expect((currentRoot["integrity"] as? String)?.utf8.count == 64)

            let roundTrip = try GamePayload.decodeMessage(from: currentWire)
            #expect(roundTrip == first)
            #expect(roundTrip.revision == first.revision)
        }
    }

    @Test("frozen cases retain their legacy migration semantics")
    func frozenCorpusSemantics() throws {
        let implicitLobby = try lobby(.implicitV0Lobby)
        #expect(implicitLobby.version == 0)
        #expect(implicitLobby.seats.map(\.id) == ["alice", "bob"])
        #expect(implicitLobby.maxPlayers == 4)
        #expect(implicitLobby.startingStack == 500)

        let versionedLobby = try lobby(.v1Lobby)
        #expect(versionedLobby.tableID == "corpus-lobby-v1")
        #expect(versionedLobby.version == 4)
        #expect(versionedLobby.seats.map(\.id) == ["p0"])

        let oldMarkerFixture = try fixture(.v0HeadsUpOldMarkers)
        let oldMarkerJSON = try #require(String(data: decodedWire(oldMarkerFixture.wire), encoding: .utf8))
        #expect(!oldMarkerJSON.contains("lastActionBet"))
        #expect(oldMarkerJSON.contains(#""hasActed":true"#))
        let headsUp = try game(.v0HeadsUpOldMarkers)
        #expect(headsUp.players.count == 2)
        #expect(headsUp.players[0].lastActionBet == 20)
        #expect(headsUp.players[0].lastAction == .call)
        #expect(headsUp.currentToAct == 1)

        let multiway = try game(.v1LiveMultiway)
        #expect(multiway.players.count == 3)
        #expect(multiway.street == .preflop)
        #expect(multiway.results == nil)
        #expect(multiway.players[1].lastAction == .call)
        #expect(multiway.currentToAct == 2)

        let unmatchedRaw = try rawGame(.v1UnmatchedBlind)
        let unmatchedRawResults = try #require(unmatchedRaw["results"] as? [[String: Any]])
        #expect(unmatchedRawResults.first?["amountWon"] as? Int == 30)
        let unmatched = try game(.v1UnmatchedBlind)
        #expect(unmatched.street == .showdown)
        #expect(unmatched.results?.first?.amountWon == 20)
        #expect(unmatched.displayPot == 20)
        #expect(unmatched.players.map(\.stack) == [990, 1_010])

        let alternateRaw = try rawGame(.v1AlternateBestFive)
        let alternateRawResults = try #require(alternateRaw["results"] as? [[String: Any]])
        let alternateCodes = try #require(alternateRawResults.first?["bestFive"] as? [Int])
        let alternateCards = alternateCodes.compactMap(Card.init(code:))
        let showdown = try game(.v1AlternateBestFive)
        let canonicalCards = try #require(showdown.results?.first?.bestFive)
        #expect(showdown.street == .showdown)
        #expect(showdown.board.count == 5)
        #expect(alternateCards.count == 5)
        #expect(Set(alternateCards) != Set(canonicalCards))
        #expect(HandEvaluator.evaluate(alternateCards) == HandEvaluator.evaluate(canonicalCards))
        #expect(showdown.results?.first?.handName == "Four of a Kind")
    }

    private func fixture(_ id: FixtureID) throws -> Fixture {
        try #require(Self.fixtures.first { $0.id == id })
    }

    private func lobby(_ id: FixtureID) throws -> Lobby {
        guard case .lobby(let lobby) = try GamePayload.decodeMessage(from: fixture(id).wire) else {
            throw CorpusError.wrongPhase
        }
        return lobby
    }

    private func game(_ id: FixtureID) throws -> GameState {
        guard case .game(let game) = try GamePayload.decodeMessage(from: fixture(id).wire) else {
            throw CorpusError.wrongPhase
        }
        return game
    }

    private func rawGame(_ id: FixtureID) throws -> [String: Any] {
        let root = try object(from: decodedWire(fixture(id).wire))
        let wrapper = try #require(root["game"] as? [String: Any])
        return try #require(wrapper["_0"] as? [String: Any])
    }

    private func decodedWire(_ wire: String) throws -> Data {
        let isCompressed = wire.first == "z"
        let payload = isCompressed ? String(wire.dropFirst()) : wire
        let data = try #require(Data(base64URLEncoded: payload))
        return try isCompressed
            ? (data as NSData).decompressed(using: .lzfse) as Data
            : data
    }

    private func object(from data: Data) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func hash(_ wire: String) -> String {
        SHA256.hash(data: Data(wire.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private enum CorpusError: Error { case wrongPhase }
}
