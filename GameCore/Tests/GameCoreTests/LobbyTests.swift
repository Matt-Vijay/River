import Testing
import Foundation
@testable import GameCore

@Suite("Lobby")
struct LobbyTests {
    @Test("joining adds seats up to the max of 6")
    func joinCap() {
        var message = TableMessage.lobby(Lobby())
        for index in 0..<6 {
            guard case .applied(let next) = message.committing(
                .joinLobby(name: "p\(index)", avatar: "🙂"),
                actorID: "p\(index)"
            ) else {
                Issue.record("expected seat \(index) to join")
                return
            }
            message = next
        }
        guard case .lobby(let lobby) = message else { return }
        #expect(lobby.seats.count == 6)   // capped
        #expect(lobby.isFull)
        #expect(
            message.committing(
                .joinLobby(name: "p6", avatar: "🙂"),
                actorID: "p6"
            ) == .rejected(.tableFull)
        )
    }

    @Test("seat lookup returns normalized profiles")
    func seatLookupReturnsNormalizedProfiles() {
        let lobby = Lobby()
            .fixtureSeat(
                id: "a",
                name: String(repeating: "A", count: ProfileText.maxNameLength + 4),
                avatar: "   "
            )
            .fixtureSeat(id: "b", name: "Bob", avatar: "B")

        #expect(lobby.seat(id: "a")?.name == String(repeating: "A", count: ProfileText.maxNameLength))
        #expect(lobby.seat(id: "a")?.avatar == "🙂")
        #expect(lobby.seat(id: "b")?.name == "Bob")
        #expect(lobby.seat(id: "missing") == nil)
    }

    @Test("starting requires a seated actor and two seats")
    func startRequiresTwoSeatsAndSeatedActor() {
        let oneSeat = TableMessage.lobby(
            Lobby().fixtureSeat(id: "a", name: "a", avatar: "🙂")
        )
        #expect(oneSeat.committing(.startGame(seed: 1, turnDuration: 30), actorID: "a")
                == .rejected(.illegalAction))
        #expect(oneSeat.committing(.startGame(seed: 1, turnDuration: 30), actorID: "missing")
                == .rejected(.notSeated))
    }

    @Test("invalid settings, versions, and identities are normalized")
    func invalidLobbyValuesAreNormalized() {
        let lobby = Lobby(
            tableID: "", version: -3, smallBlind: -5, bigBlind: 1, startingStack: -100,
            seats: [LobbySeat(id: "", name: "Alice", avatar: "A")]
        )

        #expect(lobby.startingStack == TableRules.defaultStartingStack)
        #expect(lobby.smallBlind == 1)
        #expect(lobby.bigBlind == 2)
        #expect(lobby.version == 0)
        #expect(!lobby.tableID.isEmpty)
        #expect(lobby.seats.count == 1)
        #expect(!lobby.seats[0].id.isEmpty)
    }

    @Test("initial seat capacity is normalized")
    func initialSeatCapacityIsNormalized() {
        let capped = Lobby(maxPlayers: 2, seats: [
            LobbySeat(id: "a", name: "Alice", avatar: "A"),
            LobbySeat(id: "b", name: "Bob", avatar: "B"),
            LobbySeat(id: "c", name: "Cara", avatar: "C"),
        ])

        let tooSmall = Lobby(maxPlayers: -1)
        let tooLarge = Lobby(maxPlayers: 99, seats: (0..<8).map {
            LobbySeat(id: "p\($0)", name: "P\($0)", avatar: "🙂")
        })

        #expect(capped.seats.map(\.id) == ["a", "b"])
        #expect(capped.isFull)
        #expect(tooSmall.maxPlayers == TableRules.minPlayers)
        #expect(!tooSmall.isFull)
        #expect(tooLarge.maxPlayers == TableRules.maxPlayers)
        #expect(tooLarge.seats.count == TableRules.maxPlayers)
        #expect(tooLarge.isFull)
    }

    @Test("initial duplicate seats are merged by player identity")
    func initialDuplicateSeatsAreMergedByPlayerIdentity() {
        let lobby = Lobby(seats: [
            LobbySeat(id: "a", name: "Alice", avatar: "A"),
            LobbySeat(id: "b", name: "Bob", avatar: "B"),
            LobbySeat(id: "a", name: "Updated Alice", avatar: "A2"),
        ])

        #expect(lobby.seats.map(\.id) == ["a", "b"])
        #expect(lobby.seat(id: "a")?.name == "Updated Alice")
        #expect(lobby.seat(id: "a")?.avatar == "A2")
    }

    @Test("lobby round-trips through the TableMessage payload")
    func lobbyOverWire() throws {
        let lobby = Lobby()
            .fixtureSeat(id: "a", name: "a", avatar: "🦊")
        let message = TableMessage.lobby(lobby)
        let wire = try GamePayload.encode(message)
        let decoded = try GamePayload.decodeMessage(from: wire)
        #expect(decoded == message)
    }

    @Test("equal-version lobby branches converge through the next join")
    func equalVersionLobbyBranchesConverge() {
        let base = TableMessage.lobby(
            Lobby(tableID: "table-123")
                .fixtureSeat(id: "host", name: "Host", avatar: "H")
        )
        guard case .applied(let left) = base.committing(
            .joinLobby(name: "Alice", avatar: "A"), actorID: "a"
        ), case .applied(let right) = base.committing(
            .joinLobby(name: "Bob", avatar: "B"), actorID: "b"
        ) else {
            Issue.record("expected both concurrent joins to apply")
            return
        }

        #expect(left.revision.version == right.revision.version)
        #expect(left.revision != right.revision)
        #expect(
            left.revision.isSameOrNewer(than: right.revision)
                != right.revision.isSameOrNewer(than: left.revision)
        )

        let winner = left.revision.isSameOrNewer(than: right.revision) ? left : right
        guard case .lobby(let winningLobby) = winner else { return }
        let missing = winningLobby.seat(id: "a") == nil
            ? (id: "a", name: "Alice", avatar: "A")
            : (id: "b", name: "Bob", avatar: "B")
        guard case .applied(let merged) = winner.committing(
            .joinLobby(name: missing.name, avatar: missing.avatar), actorID: missing.id
        ) else {
            Issue.record("expected the displaced participant to rejoin")
            return
        }
        guard case .lobby(let mergedLobby) = merged else { return }

        #expect(Set(mergedLobby.seats.map(\.id)) == Set(["host", "a", "b"]))
        #expect(merged.revision.isSameOrNewer(than: left.revision))
        #expect(merged.revision.isSameOrNewer(than: right.revision))
    }

    @Test("legacy readiness fields decode without controlling the lobby")
    func legacyReadinessFieldIsIgnoredByTransitions() throws {
        let legacyJSON = #"{"lobby":{"_0":{"bigBlind":10,"maxPlayers":6,"seats":[{"avatar":"A","id":"a","isReady":true,"name":"Alice"}],"smallBlind":5,"startingStack":1000,"tableID":"table-legacy","version":0}}}"#
        let wire = Data(legacyJSON.utf8).base64URLEncodedString()

        guard case .lobby(let decoded) = try GamePayload.decodeMessage(from: wire) else {
            Issue.record("expected legacy lobby")
            return
        }
        #expect(decoded.seats.count == 1)

        guard case .applied(.lobby(let joined)) = TableMessage.lobby(decoded).committing(
            .joinLobby(name: "Bob", avatar: "B"), actorID: "b"
        ) else {
            Issue.record("expected legacy lobby to accept a new seat")
            return
        }
        guard case .applied(.game) = TableMessage.lobby(joined).committing(
            .startGame(seed: 1, turnDuration: 30), actorID: "a"
        ) else {
            Issue.record("expected explicit start to work after legacy decode")
            return
        }
    }

    @Test("blank actors cannot join a lobby")
    func blankActorsCannotJoinLobby() {
        let message = TableMessage.lobby(Lobby(tableID: "table-123"))
        #expect(
            message.committing(
                .joinLobby(name: "Alice", avatar: "A"),
                actorID: ""
            ) == .rejected(.notSeated)
        )
    }

    @Test("explicit start preserves lobby seats")
    func explicitStartPreservesLobbySeats() {
        let now = Date(timeIntervalSince1970: 1_234)
        let lobby = Lobby(tableID: "table-123")
            .fixtureSeat(id: "a", name: "Alice", avatar: "A")
            .fixtureSeat(id: "b", name: "Bob", avatar: "B")
        guard case .applied(.game(let state)) = TableMessage.lobby(lobby).committing(
            .startGame(seed: 7, turnDuration: 30),
            actorID: "b", now: now
        ) else {
            Issue.record("expected game start")
            return
        }
        #expect(state.players.map(\.id) == ["a", "b"])
        #expect(state.players.map(\.name) == ["Alice", "Bob"])
        #expect(state.players.map(\.avatar) == ["A", "B"])
        #expect(state.turnStartedAt == now)
    }

    @Test("a leave advances the lobby revision once")
    func lobbyOperationAdvancesRevisionOnce() {
        let lobby = Lobby(tableID: "table-123")
            .fixtureSeat(id: "a", name: "Alice", avatar: "A")
            .fixtureSeat(id: "b", name: "Old Bob", avatar: "B")
        guard case .applied(.lobby(let next)) = TableMessage.lobby(lobby).committing(
            .leaveLobby,
            actorID: "b"
        ) else {
            Issue.record("expected applied lobby")
            return
        }
        #expect(next.version == lobby.version + 1)
        #expect(next.seat(id: "b") == nil)
    }

    @Test("no-op lobby changes are unchanged")
    func noOpLobbyChangesAreUnchanged() {
        let lobby = Lobby(tableID: "table-123")
            .fixtureSeat(id: "a", name: "Alice", avatar: "A")
            .fixtureSeat(id: "b", name: "Bob", avatar: "B")
        let message = TableMessage.lobby(lobby)
        #expect(
            message.committing(
                .joinLobby(name: "Alice", avatar: "A"),
                actorID: "a"
            ) == .unchanged
        )
    }

    @Test("changed lobby operations reject an exhausted revision")
    func exhaustedRevisionRejectsChanges() {
        let message = TableMessage.lobby(Lobby(
            tableID: "table-123", version: Int.max,
            seats: [LobbySeat(id: "a", name: "Alice", avatar: "A")]
        ))
        let changes: [(TableOperation, String)] = [
            (.joinLobby(name: "Bob", avatar: "B"), "b"),
            (.startGame(seed: 7, turnDuration: 30), "a"),
            (.leaveLobby, "a"),
        ]
        for change in changes {
            #expect(
                message.committing(
                    change.0, actorID: change.1
                ) == .rejected(.illegalAction)
            )
        }
    }
}
