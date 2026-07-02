import Testing
@testable import GameCore

@Suite("Side-pot message passing")
struct SidePotMessagePassingTests {
    @Test("3-way all-in resolves side pots correctly through the serialization layer")
    func sidePotsOverWire() throws {
        // Each step encodes then decodes, so the side-pot math must survive the wire.
        var wire = try GamePayload.encodeToString(
            GameState.startHand(players: [
                Player(id: "p0", name: "p0", avatar: "🙂", stack: 100),
                Player(id: "p1", name: "p1", avatar: "🙂", stack: 50),
                Player(id: "p2", name: "p2", avatar: "🙂", stack: 200),
            ], dealerIndex: 0, smallBlind: 10, bigBlind: 20, seed: 5, handNumber: 1))

        func act(_ make: (inout GameState) -> Void) throws {
            var s = try GamePayload.decode(fromString: wire)
            make(&s)
            wire = try GamePayload.encodeToString(s)
        }
        try act { $0.apply(.raise(to: 100), by: 0) }  // p0 shoves
        try act { $0.apply(.call, by: 1) }            // p1 all-in for 50
        try act { $0.apply(.call, by: 2) }            // p2 calls 100

        let final = try GamePayload.decode(fromString: wire)
        #expect(final.street == .showdown)
        #expect(final.players.reduce(0) { $0 + $1.stack } == 350)
        let results = try #require(final.results)
        let p1Won = try #require(results.first { $0.playerID == "p1" }).amountWon
        #expect(p1Won == 0 || p1Won == 150)
    }
}
