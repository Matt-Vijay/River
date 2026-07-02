import Testing
@testable import GameCore

@Suite("Payload durability")
struct PayloadDurabilityTests {
    @Test("the payload survives many sequential round-trips unchanged in meaning")
    func repeatedRoundTrips() throws {
        var state = GameState.startHand(players: [
            Player(id: "a", name: "a", avatar: "🙂", stack: 1000),
            Player(id: "b", name: "b", avatar: "🙂", stack: 1000),
        ], dealerIndex: 0, smallBlind: 10, bigBlind: 20, seed: 3, handNumber: 1)
        for _ in 0..<10 {
            let wire = try GamePayload.encodeToString(state)
            state = try GamePayload.decode(fromString: wire)
        }
        #expect(state.players[0].holeCards.count == 2)
        #expect(state.currentBet == 20)
    }
}
