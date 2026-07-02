import Testing
@testable import GameCore

@Suite("Player payments")
struct PlayerPaymentTests {
    @Test("non-positive payments do not change player chips")
    func nonPositivePaymentsAreIgnored() {
        var s = GameState.startHand(players: makePlayers([1000, 1000]),
                                    dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                    seed: 1, handNumber: 1)
        let before = s.players[0]

        s.pay(0, additional: -10)
        s.pay(0, additional: 0)

        #expect(s.players[0] == before)
    }

    @Test("non-positive blinds do not change player chips")
    func nonPositiveBlindsAreIgnored() {
        var s = GameState.startHand(players: makePlayers([1000, 1000]),
                                    dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                    seed: 1, handNumber: 1)
        let before = s.players[0]

        s.postBlind(0, amount: -10)
        s.postBlind(0, amount: 0)

        #expect(s.players[0] == before)
    }

    @Test("collecting bets ignores negative pending bets")
    func collectingBetsIgnoresNegativeBets() {
        var s = GameState.startHand(players: makePlayers([1000, 1000]),
                                    dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                    seed: 1, handNumber: 1)
        s.players[0].bet = -10
        s.players[1].bet = 20
        s.pot = 5

        s.collectBets()

        #expect(s.pot == 25)
        #expect(s.players[0].bet == 0)
        #expect(s.players[1].bet == 0)
    }
}
