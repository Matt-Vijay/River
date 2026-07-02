import Testing
@testable import GameCore

@Suite("Table operation kinds")
struct TableOperationKindTests {
    @Test("operation profile payloads are normalized on construction")
    func operationProfilePayloadsAreNormalizedOnConstruction() {
        let revision = TableRevision(tableID: "table-123", phase: .lobby, version: 0)
        let join = TableOperation(id: "op-1", actorID: "a", baseRevision: revision,
                                  kind: .joinLobby(name: "  Alice  ", avatar: "  A  "))
        let ready = TableOperation(id: "op-2", actorID: "a", baseRevision: revision,
                                   kind: .setReady(isReady: true, name: "   ",
                                                   avatar: "   ", startSeed: 1,
                                                   turnDuration: 30))

        #expect(join.kind == .joinLobby(name: "Alice", avatar: "A"))
        #expect(ready.kind == .setReady(isReady: true, startSeed: 1,
                                        turnDuration: 30))
    }

    @Test("operation numeric payloads are normalized on construction")
    func operationNumericPayloadsAreNormalizedOnConstruction() {
        let revision = TableRevision(tableID: "table-123", phase: .game, version: 0)
        let join = TableOperation(id: "op-1", actorID: "c", baseRevision: revision,
                                  kind: .joinGame(name: "Cara", avatar: "C",
                                                  startingStack: -100))
        let raise = TableOperation(id: "op-2", actorID: "a", baseRevision: revision,
                                   kind: .gameAction(.raise(to: -20)))
        let ready = TableOperation(id: "op-3", actorID: "a", baseRevision: revision,
                                   kind: .setReady(isReady: true,
                                                   startSeed: 1,
                                                   turnDuration: -.infinity))

        #expect(join.kind == .joinGame(name: "Cara", avatar: "C",
                                       startingStack: StartingStack.defaultAmount))
        #expect(raise.kind == .gameAction(.raise(to: 0)))
        #expect(ready.kind == .setReady(isReady: true,
                                        startSeed: 1,
                                        turnDuration: TurnClock.defaultDuration))
    }
}
