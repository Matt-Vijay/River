import Testing

@testable import GameCore

@Suite("Deal next hand operations")
struct DealNextHandOperationTests {
  @Test("unknown actor cannot deal the next hand")
  func unknownActorCannotDealNextHand() {
    let message = headsUpTableMessage()

    #expect(
      message.committing(.dealNextHand(seed: 2), actorID: "intruder")
        == .rejected(.notSeated))
  }

  @Test("cannot deal the next hand while the current hand is in progress")
  func cannotDealNextHandDuringLiveHand() {
    let message = headsUpTableMessage()

    #expect(
      message.committing(.dealNextHand(seed: 2), actorID: "a")
        == .rejected(.illegalAction))
  }

  @Test("dealing the next hand preserves joined player identity")
  func dealNextHandPreservesJoinedIdentity() throws {
    let live = headsUpTableMessage()
    guard case .applied(.game(let completed)) = live.committing(
      .gameAction(.fold), actorID: "a")
    else {
      Issue.record("expected completed hand")
      return
    }

    let message = TableMessage.game(completed)

    guard case .applied(.game(let next)) = message.committing(
      .dealNextHand(seed: 2), actorID: "b"),
      let bob = next.players.first(where: { $0.id == "b" })
    else {
      Issue.record("expected next hand")
      return
    }

    #expect(next.handNumber == 2)
    #expect(bob.name == "Bob")
    #expect(bob.avatar == "B")
    #expect(message.revision.isOlder(than: TableMessage.game(next).revision))
  }

}
