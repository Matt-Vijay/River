import Testing
import Foundation
@testable import GameCore

@Suite("Timeout message passing")
struct TimeoutMessagePassingTests {
    @Test("a timed-out turn is resolved by the next client through the wire")
    func lazyTimeoutOverWire() throws {
        let start = Date()
        let wire = try GamePayload.encodeToString(
            GameState.startHand(players: [
                Player(id: "a", name: "a", avatar: "🙂", stack: 1000),
                Player(id: "b", name: "b", avatar: "🙂", stack: 1000),
            ], dealerIndex: 0, smallBlind: 10, bigBlind: 20,
               seed: 1, handNumber: 1, turnDuration: 30, now: start))

        var received = try GamePayload.decode(fromString: wire)
        received.resolveTimeout(now: start.addingTimeInterval(45))
        let resent = try GamePayload.decode(fromString: try GamePayload.encodeToString(received))

        #expect(resent.players[0].status == .folded)
        #expect(resent.players[1].stack == 1010)
    }
}
