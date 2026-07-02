import Testing
import Foundation
@testable import GameCore

@Suite("Lobby")
struct LobbyTests {
    @Test("joining adds seats up to the max of 6")
    func joinCap() {
        var lobby = Lobby()
        for i in 0..<8 {
            lobby = lobby.adding(id: "p\(i)", name: "p\(i)", avatar: "🙂")
        }
        #expect(lobby.seats.count == 6)   // capped
        #expect(lobby.isFull)
    }

    @Test("joining twice is a no-op")
    func noDoubleJoin() {
        let lobby = Lobby()
            .adding(id: "a", name: "a", avatar: "🙂")
            .adding(id: "a", name: "a", avatar: "🙂")
        #expect(lobby.seats.count == 1)
    }

    @Test("joining again preserves the existing lobby profile")
    func joiningAgainPreservesProfile() {
        let lobby = Lobby()
            .adding(id: "a", name: "Alice", avatar: "A")
            .adding(id: "a", name: "Updated Alice", avatar: "A2")

        #expect(lobby.seats.count == 1)
        #expect(lobby.seat(id: "a")?.name == "Alice")
        #expect(lobby.seat(id: "a")?.avatar == "A")
    }

    @Test("seat lookup and readiness hide seat-array details")
    func seatLookup() {
        let lobby = Lobby()
            .adding(id: "a", name: "Alice", avatar: "A")
            .adding(id: "b", name: "Bob", avatar: "B")
            .updating(id: "b", isReady: true)

        #expect(lobby.seat(id: "a")?.name == "Alice")
        #expect(lobby.contains("a"))
        #expect(lobby.isReady(id: "a") == false)
        #expect(lobby.isReady(id: "b") == true)
        #expect(lobby.seat(id: "missing") == nil)
        #expect(lobby.isReady(id: "missing") == false)
    }

    @Test("seat profile text is normalized")
    func seatProfileTextIsNormalized() {
        let lobby = Lobby()
            .adding(id: "a", name: "  Alice  ", avatar: "  A  ")
            .updating(id: "a", name: String(repeating: "A", count: ProfileText.maxNameLength + 4), avatar: "   ")

        #expect(lobby.seat(id: "a")?.name == String(repeating: "A", count: ProfileText.maxNameLength))
        #expect(lobby.seat(id: "a")?.avatar == "🙂")

        let blank = lobby.updating(id: "a", name: "   ")
        #expect(blank.seat(id: "a")?.name == "Player")
    }

    @Test("canStart requires 2+ players all ready")
    func canStartRule() {
        var lobby = Lobby().adding(id: "a", name: "a", avatar: "🙂")
        #expect(lobby.canStart == false)                 // only one player
        lobby = lobby.adding(id: "b", name: "b", avatar: "🙂")
        #expect(lobby.canStart == false)                 // nobody ready
        lobby = lobby.updating(id: "a", isReady: true)
        #expect(lobby.canStart == false)                 // only one ready
        lobby = lobby.updating(id: "b", isReady: true)
        #expect(lobby.canStart == true)                  // all ready
    }

    @Test("safe start requires lobby readiness")
    func safeStartRequiresReadiness() {
        var lobby = Lobby()
            .adding(id: "a", name: "a", avatar: "🙂")
            .adding(id: "b", name: "b", avatar: "🙂")

        #expect(lobby.startIfReady(seed: 1) == nil)

        lobby = lobby
            .updating(id: "a", isReady: true)
            .updating(id: "b", isReady: true)

        #expect(lobby.startIfReady(seed: 1)?.players.map(\.id) == ["a", "b"])
    }

    @Test("starting deals every seat in with the starting stack")
    func startDealsIn() {
        let lobby = Lobby(startingStack: 1000)
            .adding(id: "a", name: "Alice", avatar: "🦊")
            .adding(id: "b", name: "Bob", avatar: "🐱")
            .adding(id: "c", name: "Cara", avatar: "🐼")
        let game = lobby.start(seed: 1)
        #expect(game.players.count == 3)
        #expect(game.players.allSatisfy { $0.holeCards.count == 2 })
        #expect(game.players.map(\.name) == ["Alice", "Bob", "Cara"])
        #expect(game.players.map(\.avatar) == ["🦊", "🐱", "🐼"])
        // Stacks = starting stack minus any posted blinds; total conserved.
        let total = game.players.reduce(0) { $0 + $1.stack + $1.bet }
        #expect(total == 3000)
    }

    @Test("invalid starting stacks are normalized before lobby start")
    func invalidStartingStackIsNormalized() {
        let lobby = Lobby(startingStack: -100)
            .adding(id: "a", name: "Alice", avatar: "A")
            .adding(id: "b", name: "Bob", avatar: "B")

        let game = lobby.start(seed: 1)

        #expect(lobby.startingStack == StartingStack.defaultAmount)
        #expect(game.players.allSatisfy { $0.stack + $0.bet == StartingStack.defaultAmount })
    }

    @Test("default lobby configuration uses shared table contracts")
    func defaultLobbyConfigurationUsesSharedTableContracts() {
        let lobby = Lobby()

        #expect(Lobby.defaultMaxPlayers == TableSize.maxPlayers)
        #expect(Lobby.defaultStartingStack == StartingStack.defaultAmount)
        #expect(lobby.maxPlayers == Lobby.defaultMaxPlayers)
        #expect(lobby.smallBlind == Lobby.defaultSmallBlind)
        #expect(lobby.bigBlind == Lobby.defaultBigBlind)
        #expect(lobby.startingStack == Lobby.defaultStartingStack)
    }

    @Test("invalid blind settings are normalized before lobby start")
    func invalidBlindSettingsAreNormalized() {
        let lobby = Lobby(smallBlind: -5, bigBlind: 1)
            .adding(id: "a", name: "Alice", avatar: "A")
            .adding(id: "b", name: "Bob", avatar: "B")

        let game = lobby.start(seed: 1)

        #expect(lobby.smallBlind == 1)
        #expect(lobby.bigBlind == 2)
        #expect(game.smallBlind == 1)
        #expect(game.bigBlind == 2)
        #expect(game.minRaise == 2)
    }

    @Test("negative lobby versions are normalized")
    func negativeVersionsAreNormalized() {
        let lobby = Lobby(version: -3)

        #expect(lobby.version == 0)
    }

    @Test("empty table identities are replaced")
    func emptyTableIdentitiesAreReplaced() {
        let lobby = Lobby(tableID: "")

        #expect(!lobby.tableID.isEmpty)
    }

    @Test("empty seat identities are replaced")
    func emptySeatIdentitiesAreReplaced() {
        let lobby = Lobby(seats: [
            LobbySeat(id: "", name: "Alice", avatar: "A"),
        ])

        #expect(lobby.seats.count == 1)
        #expect(!lobby.seats[0].id.isEmpty)
    }

    @Test("initial operation history is ordered and unique")
    func initialOperationHistoryIsOrderedAndUnique() {
        let lobby = Lobby(appliedOperationIDs: ["op-1", "", "op-2", "op-1", "op-3", "", "op-2"])

        #expect(lobby.appliedOperationIDs == ["op-1", "op-2", "op-3"])
    }

    @Test("initial seats are capped to max players")
    func initialSeatsAreCappedToMaxPlayers() {
        let lobby = Lobby(maxPlayers: 2, seats: [
            LobbySeat(id: "a", name: "Alice", avatar: "A"),
            LobbySeat(id: "b", name: "Bob", avatar: "B"),
            LobbySeat(id: "c", name: "Cara", avatar: "C"),
        ])

        #expect(lobby.seats.map(\.id) == ["a", "b"])
        #expect(lobby.isFull)
    }

    @Test("invalid max player counts are normalized to a playable table size")
    func invalidMaxPlayerCountsAreNormalized() {
        let tooSmall = Lobby(maxPlayers: -1)
        let tooLarge = Lobby(maxPlayers: 99, seats: (0..<8).map {
            LobbySeat(id: "p\($0)", name: "P\($0)", avatar: "🙂")
        })

        #expect(tooSmall.maxPlayers == TableSize.minPlayers)
        #expect(!tooSmall.isFull)
        #expect(tooLarge.maxPlayers == TableSize.maxPlayers)
        #expect(tooLarge.seats.count == TableSize.maxPlayers)
        #expect(tooLarge.isFull)
    }

    @Test("initial duplicate seats are merged by player identity")
    func initialDuplicateSeatsAreMergedByPlayerIdentity() {
        let lobby = Lobby(seats: [
            LobbySeat(id: "a", name: "Alice", avatar: "A"),
            LobbySeat(id: "b", name: "Bob", avatar: "B"),
            LobbySeat(id: "a", name: "Updated Alice", avatar: "A2", isReady: true),
        ])

        #expect(lobby.seats.map(\.id) == ["a", "b"])
        #expect(lobby.seat(id: "a")?.name == "Updated Alice")
        #expect(lobby.seat(id: "a")?.avatar == "A2")
        #expect(lobby.seat(id: "a")?.isReady == true)
    }

    @Test("lobby round-trips through the TableMessage payload")
    func lobbyOverWire() throws {
        let lobby = Lobby()
            .adding(id: "a", name: "a", avatar: "🦊")
            .updating(id: "a", isReady: true)
        let wire = try GamePayload.encodeToString(TableMessage.lobby(lobby))
        guard case .lobby(let decoded) = try GamePayload.decodeMessage(fromString: wire) else {
            Issue.record("expected lobby"); return
        }
        #expect(decoded == lobby)
    }
}
