import Testing
import Foundation
@testable import GameCore

@Suite("Lazy timeout")
struct TimeoutTests {
    @Test("a stale turn facing a bet is folded by the next client")
    func staleFold() {
        let start = Date()
        var s = GameState.startHand(players: makePlayers([1000, 1000]),
                                    dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                    seed: 1, handNumber: 1, turnDuration: 30, now: start)
        // Dealer (to act, facing the BB) goes idle past the clock.
        let later = start.addingTimeInterval(45)
        let resolved = s.resolveTimeout(now: later)
        #expect(resolved == true)
        #expect(s.players[0].status == .folded)
        #expect(s.players[1].stack == 1010)  // BB wins uncontested
    }

    @Test("a fresh turn is not resolved")
    func freshTurnUntouched() {
        let start = Date()
        var s = GameState.startHand(players: makePlayers([1000, 1000]),
                                    dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                    seed: 1, handNumber: 1, turnDuration: 30, now: start)
        let soon = start.addingTimeInterval(10)
        #expect(s.resolveTimeout(now: soon) == false)
        #expect(s.players[0].status == .active)
    }

    @Test("a turn resolves exactly at the deadline")
    func turnResolvesExactlyAtDeadline() {
        let start = Date()
        var s = GameState.startHand(players: makePlayers([1000, 1000]),
                                    dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                    seed: 1, handNumber: 1, turnDuration: 30, now: start)

        let deadline = start.addingTimeInterval(30)

        #expect(s.resolveTimeout(now: deadline) == true)
        #expect(s.players[0].status == .folded)
    }

    @Test("an invalid current actor index is not resolved")
    func invalidCurrentActorIsIgnored() {
        let start = Date()
        var s = GameState.startHand(players: makePlayers([1000, 1000]),
                                    dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                    seed: 1, handNumber: 1, turnDuration: 30, now: start)
        s.currentToAct = 99

        let resolved = s.resolveTimeout(now: start.addingTimeInterval(45))

        #expect(resolved == false)
        #expect(s.players[0].status == .active)
        #expect(s.players[1].status == .active)
    }

    @Test("stale non-actable current player is not resolved")
    func staleNonActableCurrentPlayerIsIgnored() {
        let start = Date()
        var s = GameState.startHand(players: makePlayers([1000, 1000]),
                                    dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                    seed: 1, handNumber: 1, turnDuration: 30, now: start)
        s.players[0].status = .folded

        let resolved = s.resolveTimeout(now: start.addingTimeInterval(45))

        #expect(resolved == false)
        #expect(s.players[0].lastAction == nil)
    }

    @Test("a stale actor who has already matched the bet checks")
    func staleActorWithNoCallAmountChecks() {
        let start = Date()
        var s = GameState.startHand(players: makePlayers([1000, 1000]),
                                    dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                    seed: 1, handNumber: 1, turnDuration: 30, now: start)
        s.players[0].bet = 30
        s.currentBet = 20

        let beforeStack = s.players[0].stack
        let resolved = s.resolveTimeout(now: start.addingTimeInterval(45))

        #expect(resolved == true)
        #expect(s.players[0].status == .active)
        #expect(s.players[0].lastAction == .check)
        #expect(s.players[0].stack == beforeStack)
    }
}
