import Testing
@testable import GameCore

@Suite("Deal next hand operations")
struct DealNextHandOperationTests {
    @Test("unknown actor cannot deal the next hand")
    func unknownActorCannotDealNextHand() {
        let message = headsUpTableMessage()
        let operation = TableOperation(id: "op-1", actorID: "intruder",
                                       baseRevision: message.revision,
                                       kind: .dealNextHand(seed: 2))

        #expect(message.applying(operation) == .rejected(.notSeated))
    }

    @Test("cannot deal the next hand while the current hand is in progress")
    func cannotDealNextHandDuringLiveHand() {
        let message = headsUpTableMessage()
        let operation = TableOperation(id: "op-1", actorID: "a",
                                       baseRevision: message.revision,
                                       kind: .dealNextHand(seed: 2))

        #expect(message.applying(operation) == .rejected(.illegalAction))
    }

    @Test("dealing the next hand preserves joined player identity")
    func dealNextHandPreservesJoinedIdentity() throws {
        let live = headsUpTableMessage()
        let fold = TableOperation(id: "op-1", actorID: "a",
                                  baseRevision: live.revision,
                                  kind: .gameAction(.fold))
        guard case .applied(.game(let completed)) = live.applying(fold) else {
            Issue.record("expected completed hand")
            return
        }

        let message = TableMessage.game(completed)
        let nextHand = TableOperation(id: "op-2", actorID: "b",
                                      baseRevision: message.revision,
                                      kind: .dealNextHand(seed: 2,
                                                          name: "Mallory",
                                                          avatar: "X"))

        guard case .applied(.game(let next)) = message.applying(nextHand),
              let bob = next.players.first(where: { $0.id == "b" }) else {
            Issue.record("expected next hand")
            return
        }

        #expect(next.handNumber == 2)
        #expect(bob.name == "Bob")
        #expect(bob.avatar == "B")
    }

    @Test("dealing the next hand advances the message revision")
    func dealNextHandAdvancesMessageRevision() throws {
        let live = headsUpTableMessage()
        let fold = TableOperation(id: "op-1", actorID: "a",
                                  baseRevision: live.revision,
                                  kind: .gameAction(.fold))
        guard case .applied(.game(let completed)) = live.applying(fold) else {
            Issue.record("expected completed hand")
            return
        }

        let message = TableMessage.game(completed)
        let nextHand = TableOperation(id: "op-2", actorID: "b",
                                      baseRevision: message.revision,
                                      kind: .dealNextHand(seed: 2))

        guard case .applied(let nextMessage) = message.applying(nextHand) else {
            Issue.record("expected next hand")
            return
        }

        #expect(message.revision.isOlder(than: nextMessage.revision))
    }

    @Test("busted actor cannot deal the next hand")
    func bustedActorCannotDealNextHand() {
        var state = GameState.startHand(players: makePlayers([1000, 1000, 1000]),
                                        dealerIndex: 0,
                                        smallBlind: 10,
                                        bigBlind: 20,
                                        seed: 1,
                                        handNumber: 1,
                                        tableID: "table-123")
        state.players[0].stack = 0
        state.players[0].status = .sittingOut
        state.results = [
            HandResult(playerID: state.players[1].id, amountWon: 30, handName: nil, bestFive: nil)
        ]

        let message = TableMessage.game(state)
        let operation = TableOperation(id: "op-1",
                                       actorID: state.players[0].id,
                                       baseRevision: message.revision,
                                       kind: .dealNextHand(seed: 2))

        #expect(state.canDealNextHand(actorID: state.players[0].id) == false)
        #expect(state.canDealNextHand(actorID: state.players[1].id) == true)
        #expect(message.applying(operation) == .rejected(.notSeated))
    }
}
