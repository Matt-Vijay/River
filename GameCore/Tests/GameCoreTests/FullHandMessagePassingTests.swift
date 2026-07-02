import Testing
@testable import GameCore

@Suite("Full-hand message passing")
struct FullHandMessagePassingTests {
    @Test("heads-up: a full hand completes purely via encoded payloads")
    func headsUpOverWire() throws {
        let final = try playFullHandOverTheWire(playerCount: 2, seed: 1)
        #expect(final.street == .showdown)
        #expect(final.results != nil)
        #expect(final.board.count == 5)
        #expect(final.players.reduce(0) { $0 + $1.stack } == 2000)  // chips conserved
    }

    @Test("heads-up: a full hand completes via encoded operation envelopes")
    func headsUpOverOperationWire() throws {
        let final = try playFullHandWithOperationsOverTheWire(playerCount: 2, seed: 1)
        #expect(final.street == .showdown)
        #expect(final.results != nil)
        #expect(final.board.count == 5)
        #expect(final.players.reduce(0) { $0 + $1.stack } == 2000)
    }

    @Test("group chat: a 5-handed hand completes purely via encoded payloads")
    func groupOverWire() throws {
        let final = try playFullHandOverTheWire(playerCount: 5, seed: 7)
        let results = try #require(final.results)
        #expect(final.players.reduce(0) { $0 + $1.stack } == 5000)
        // Exactly one pot's worth was won across the contenders.
        let won = results.reduce(0) { $0 + $1.amountWon }
        #expect(won == final.players.reduce(0) { $0 + $1.committed })
    }
}
