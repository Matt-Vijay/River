import Testing
import Foundation
@testable import GameCore

@Suite("Table lobby operations")
struct TableLobbyOperationTests {
    @Test("blank actors cannot join a lobby")
    func blankActorsCannotJoinLobby() {
        let message = TableMessage.lobby(Lobby(tableID: "table-123"))
        let operation = TableOperation(id: "op-1", actorID: "", baseRevision: message.revision,
                                       kind: .joinLobby(name: "Alice", avatar: "A"))

        #expect(message.applying(operation) == .rejected(.notSeated))
    }

    @Test("whitespace actors cannot join a lobby")
    func whitespaceActorsCannotJoinLobby() {
        let message = TableMessage.lobby(Lobby(tableID: "table-123"))
        let operation = TableOperation(id: "op-1", actorID: "   ", baseRevision: message.revision,
                                       kind: .joinLobby(name: "Alice", avatar: "A"))

        #expect(message.applying(operation) == .rejected(.notSeated))
    }

    @Test("lobby operation preflight rejects locally stale selected messages")
    func lobbyOperationPreflightRejectsLocallyStaleSelectedMessages() {
        let message = TableMessage.lobby(Lobby(tableID: "table-123"))
        let latest = TableRevision(tableID: message.revision.tableID,
                                   phase: message.revision.phase,
                                   version: message.revision.version + 1)
        let tracker = TableRevisionTracker(revisions: [latest])
        let operation = TableOperation(id: "op-1", actorID: "a",
                                       baseRevision: message.revision,
                                       kind: .joinLobby(name: "Alice", avatar: "A"))

        #expect(message.applying(operation, knownBy: tracker) == .rejected(.stale(expected: latest)))
    }

    @Test("duplicate lobby operation replay is acknowledged before stale preflight")
    func duplicateLobbyOperationReplayIsAcknowledgedBeforeStalePreflight() {
        var lobby = Lobby(tableID: "table-123")
            .adding(id: "a", name: "Alice", avatar: "A")
        lobby.appliedOperationIDs = ["op-1"]
        let message = TableMessage.lobby(lobby)
        let latest = TableRevision(tableID: message.revision.tableID,
                                   phase: message.revision.phase,
                                   version: message.revision.version + 1)
        let tracker = TableRevisionTracker(revisions: [latest])
        let operation = TableOperation(id: "op-1", actorID: "a",
                                       baseRevision: message.revision,
                                       kind: .joinLobby(name: "Alice", avatar: "A"))

        #expect(message.applying(operation, knownBy: tracker) == .unchanged(message))
    }

    @Test("ready operation can transition a full ready lobby into a game")
    func readyCanStartGame() throws {
        let now = Date(timeIntervalSince1970: 1_234)
        let lobby = Lobby(tableID: "table-123")
            .adding(id: "a", name: "Alice", avatar: "A")
            .adding(id: "b", name: "Bob", avatar: "B")
            .updating(id: "a", isReady: true)
        let message = TableMessage.lobby(lobby)
        let operation = TableOperation(id: "op-1", actorID: "b", baseRevision: message.revision,
                                       kind: .setReady(isReady: true, startSeed: 7, turnDuration: 30))

        guard case .applied(.game(let state)) = message.applying(operation, now: now) else {
            Issue.record("expected game start")
            return
        }
        #expect(state.tableID == "table-123")
        #expect(state.players.map(\.id) == ["a", "b"])
        #expect(state.turnStartedAt == now)
    }

    @Test("ready operation starts with the joined profile")
    func readyStartsWithJoinedProfile() throws {
        let lobby = Lobby(tableID: "table-123")
            .adding(id: "a", name: "Alice", avatar: "A")
            .adding(id: "b", name: "Old Bob", avatar: "B")
            .updating(id: "a", isReady: true)
        let message = TableMessage.lobby(lobby)
        let operation = TableOperation(id: "op-1", actorID: "b", baseRevision: message.revision,
                                       kind: .setReady(isReady: true,
                                                       name: "Mallory",
                                                       avatar: "X",
                                                       startSeed: 7,
                                                       turnDuration: 30))

        guard case .applied(.game(let state)) = message.applying(operation),
              let bob = state.players.first(where: { $0.id == "b" }) else {
            Issue.record("expected game start with bob seated")
            return
        }
        #expect(bob.name == "Old Bob")
        #expect(bob.avatar == "B")
    }

    @Test("one lobby operation advances the revision once")
    func lobbyOperationAdvancesRevisionOnce() throws {
        let lobby = Lobby(tableID: "table-123")
            .adding(id: "a", name: "Alice", avatar: "A")
            .adding(id: "b", name: "Old Bob", avatar: "B")
        let message = TableMessage.lobby(lobby)
        let operation = TableOperation(id: "op-1", actorID: "b", baseRevision: message.revision,
                                       kind: .setReady(isReady: true,
                                                       name: "Bob",
                                                       avatar: "B2",
                                                       startSeed: 7,
                                                       turnDuration: 30))

        guard case .applied(.lobby(let next)) = message.applying(operation) else {
            Issue.record("expected applied lobby")
            return
        }

        #expect(next.version == lobby.version + 1)
        #expect(next.seat(id: "b")?.name == "Old Bob")
        #expect(next.seat(id: "b")?.avatar == "B")
        #expect(next.isReady(id: "b"))
    }

    @Test("profile update operations cannot rewrite joined identity")
    func profileUpdateCannotRewriteJoinedIdentity() {
        let lobby = Lobby(tableID: "table-123")
            .adding(id: "a", name: "Alice", avatar: "A")
        let message = TableMessage.lobby(lobby)
        let operation = TableOperation(id: "op-1", actorID: "a", baseRevision: message.revision,
                                       kind: .updateLobbyProfile(name: "Mallory", avatar: "X"))

        #expect(message.applying(operation) == .unchanged(message))
    }

    @Test("no-op lobby operation is unchanged")
    func noOpLobbyOperationIsUnchanged() {
        let lobby = Lobby(tableID: "table-123")
            .adding(id: "a", name: "Alice", avatar: "A")
            .adding(id: "b", name: "Bob", avatar: "B")
        let message = TableMessage.lobby(lobby)
        let operation = TableOperation(id: "op-1", actorID: "b", baseRevision: message.revision,
                                       kind: .setReady(isReady: false,
                                                       startSeed: 7,
                                                       turnDuration: 30))

        #expect(message.applying(operation) == .unchanged(message))
    }

    @Test("duplicate lobby operation is acknowledged without changing state")
    func duplicateLobbyOperationIsAcknowledgedWithoutChangingState() {
        var lobby = Lobby(tableID: "table-123")
            .adding(id: "a", name: "Alice", avatar: "A")
        lobby.appliedOperationIDs = ["op-1"]
        let message = TableMessage.lobby(lobby)
        let operation = TableOperation(id: "op-1", actorID: "a", baseRevision: message.revision,
                                       kind: .joinLobby(name: "Alice", avatar: "A"))

        #expect(message.applying(operation) == .unchanged(message))
    }

    @Test("no-op lobby join is unchanged")
    func noOpLobbyJoinIsUnchanged() {
        let lobby = Lobby(tableID: "table-123")
            .adding(id: "a", name: "Alice", avatar: "A")
        let message = TableMessage.lobby(lobby)
        let operation = TableOperation(id: "op-1", actorID: "a", baseRevision: message.revision,
                                       kind: .joinLobby(name: "Alice", avatar: "A"))

        #expect(message.applying(operation) == .unchanged(message))
    }

    @Test("no-op lobby profile update is unchanged")
    func noOpLobbyProfileUpdateIsUnchanged() {
        let lobby = Lobby(tableID: "table-123")
            .adding(id: "a", name: "Alice", avatar: "A")
        let message = TableMessage.lobby(lobby)
        let operation = TableOperation(id: "op-1", actorID: "a", baseRevision: message.revision,
                                       kind: .updateLobbyProfile(name: "Alice", avatar: "A"))

        #expect(message.applying(operation) == .unchanged(message))
    }
}
