import Testing
@testable import GameCore

@Suite("Table revisions")
struct TableRevisionTests {
    @Test("table identity survives lobby start and next hand")
    func tableIdentitySurvivesProgression() throws {
        let lobby = Lobby(tableID: "table-123")
            .adding(id: "a", name: "Alice", avatar: "🙂")
            .adding(id: "b", name: "Bob", avatar: "🙂")
            .updating(id: "a", isReady: true)
            .updating(id: "b", isReady: true)

        var state = lobby.start(seed: 1)
        state.apply(.fold, by: 0)
        let next = state.startNextHand(seed: 2)

        #expect(state.tableID == "table-123")
        #expect(next?.tableID == "table-123")
    }

    @Test("next hand keeps game revisions moving forward")
    func nextHandKeepsGameRevisionsMovingForward() throws {
        var state = GameState.startHand(players: makePlayers([1000, 1000, 1000]),
                                        dealerIndex: 0,
                                        smallBlind: 10,
                                        bigBlind: 20,
                                        seed: 1,
                                        handNumber: 1,
                                        tableID: "table-123")
        state.apply(.fold, by: 0)
        state.apply(.fold, by: 1)

        let next = try #require(state.startNextHand(seed: 2))

        #expect(state.isHandComplete)
        #expect(TableMessage.game(state).revision.isOlder(than: TableMessage.game(next).revision))
        #expect(next.version == state.version + 1)
    }

    @Test("message revisions order lobby, game, and newer game states")
    func messageRevisionOrdering() {
        let lobby = Lobby(tableID: "table-123")
        let older = GameState.startHand(players: [
            Player(id: "a", name: "Alice", avatar: "🙂", stack: 1000),
            Player(id: "b", name: "Bob", avatar: "🙂", stack: 1000),
        ], dealerIndex: 0, smallBlind: 10, bigBlind: 20, seed: 1,
           handNumber: 1, tableID: "table-123")
        let newer = older.applying(.fold, by: 0)

        #expect(TableMessage.lobby(lobby).revision.isOlder(than: TableMessage.game(older).revision))
        #expect(TableMessage.game(older).revision.isOlder(than: TableMessage.game(newer).revision))
        #expect(!TableMessage.game(newer).revision.isOlder(than: TableMessage.game(older).revision))
    }

    @Test("revision tracker remembers newest state and flags stale messages")
    func revisionTrackerFlagsStaleMessages() {
        let older = TableRevision(tableID: "table-123", phase: .game, version: 1)
        let newer = TableRevision(tableID: "table-123", phase: .game, version: 2)
        let otherTable = TableRevision(tableID: "other", phase: .game, version: 0)

        var tracker = TableRevisionTracker()
        tracker.remember(newer)

        #expect(tracker.freshness(of: older) == .stale(latest: newer))
        #expect(tracker.freshness(of: newer) == .current)
        #expect(tracker.freshness(of: otherTable) == .current)
    }

    @Test("revision tracker rebuilt from persisted revisions keeps the newest duplicate")
    func revisionTrackerRebuiltFromPersistedRevisionsKeepsNewestDuplicate() {
        let older = TableRevision(tableID: "table-123", phase: .game, version: 1)
        let newer = TableRevision(tableID: "table-123", phase: .game, version: 2)
        let staleLobby = TableRevision(tableID: "table-123", phase: .lobby, version: 0)

        let tracker = TableRevisionTracker(revisions: [newer, staleLobby, older])

        #expect(tracker.latestByTableID["table-123"] == newer)
        #expect(tracker.freshness(of: older) == .stale(latest: newer))
    }

    @Test("revision tracker dictionary input is indexed by revision table identity")
    func revisionTrackerDictionaryInputIsIndexedByRevisionTableIdentity() {
        let older = TableRevision(tableID: "table-123", phase: .game, version: 1)
        let newer = TableRevision(tableID: "table-123", phase: .game, version: 2)

        let tracker = TableRevisionTracker(latestByTableID: ["wrong-key": newer])

        #expect(tracker.latestByTableID["wrong-key"] == nil)
        #expect(tracker.latestByTableID["table-123"] == newer)
        #expect(tracker.freshness(of: older) == .stale(latest: newer))
    }

    @Test("revision tracker exposes deterministic latest revisions")
    func revisionTrackerExposesDeterministicLatestRevisions() {
        let aOlder = TableRevision(tableID: "a", phase: .game, version: 1)
        let aNewer = TableRevision(tableID: "a", phase: .game, version: 2)
        let b = TableRevision(tableID: "b", phase: .lobby, version: 0)
        let c = TableRevision(tableID: "c", phase: .game, version: 1)

        let tracker = TableRevisionTracker(revisions: [c, aOlder, b, aNewer])

        #expect(tracker.latestRevisions == [aNewer, b, c])
    }

    @Test("negative versions are normalized")
    func negativeVersionsAreNormalized() {
        let revision = TableRevision(tableID: "table-123", phase: .game, version: -1)

        #expect(revision.version == 0)
    }

    @Test("empty table identities are replaced")
    func emptyTableIdentitiesAreReplaced() {
        let revision = TableRevision(tableID: "", phase: .game, version: 1)

        #expect(!revision.tableID.isEmpty)
    }

    @Test("table identities are trimmed and blank identities are replaced")
    func tableIdentitiesAreTrimmedAndBlankIdentitiesAreReplaced() {
        let padded = TableRevision(tableID: "  table-123  ", phase: .game, version: 1)
        let blank = TableRevision(tableID: "   ", phase: .game, version: 1)

        #expect(padded.tableID == "table-123")
        #expect(!blank.tableID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
}
