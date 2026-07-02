import Foundation
import Testing
@testable import GameCore

@Suite("Gameplay stress")
struct GameplayStressTests {
    @Test("deterministic mixed-action play conserves chips and keeps legal turn state")
    func deterministicMixedActionPlayConservesChipsAndKeepsLegalTurnState() {
        let fixedNow = Date(timeIntervalSince1970: 1_800_000_000)
        var chooser = DeterministicChooser(seed: 0xC0FFEE)
        var state = GameState.startHand(
            players: makePlayers([10_000, 10_000, 10_000, 10_000, 10_000, 10_000]),
            dealerIndex: 0,
            smallBlind: 10,
            bigBlind: 20,
            seed: chooser.next(),
            handNumber: 1,
            now: fixedNow
        )
        let chipTotal = totalChips(state)
        var completedHands = 0
        var appliedActions = 0

        assertStressInvariants(state, chipTotal: chipTotal)

        while completedHands < 120 {
            var handActions = 0

            while let actor = state.currentToAct {
                assertStressInvariants(state, chipTotal: chipTotal)
                let legal = state.legalActions(for: actor)
                let action = chooseAction(from: legal, chooser: &chooser)
                let previousVersion = state.version

                let applied = state.apply(action, by: actor, now: fixedNow)
                #expect(applied)
                #expect(state.version == previousVersion + 1)

                appliedActions += 1
                handActions += 1
                #expect(handActions < 300)
                if handActions >= 300 { break }
            }

            assertStressInvariants(state, chipTotal: chipTotal)
            #expect(state.isHandComplete)
            completedHands += 1

            guard completedHands < 120,
                  let next = state.startNextHand(seed: chooser.next(), now: fixedNow) else {
                break
            }
            state = next
            assertStressInvariants(state, chipTotal: chipTotal)
        }

        #expect(completedHands >= 25)
        #expect(appliedActions >= 150)
        #expect(totalChips(state) == chipTotal)
    }

    @Test("short-stack all-in stress reaches terminal states without corrupting side pots")
    func shortStackAllInStressReachesTerminalStatesWithoutCorruptingSidePots() {
        let fixedNow = Date(timeIntervalSince1970: 1_800_000_100)
        var chooser = DeterministicChooser(seed: 0xBAD5EED)
        var state = GameState.startHand(
            players: makePlayers([40, 55, 80, 125, 240]),
            dealerIndex: 2,
            smallBlind: 10,
            bigBlind: 20,
            seed: chooser.next(),
            handNumber: 1,
            now: fixedNow
        )
        let chipTotal = totalChips(state)
        var completedHands = 0

        while completedHands < 30 {
            var handActions = 0

            while let actor = state.currentToAct {
                assertStressInvariants(state, chipTotal: chipTotal)
                let legal = state.legalActions(for: actor)
                let action = chooseAllInBiasedAction(from: legal, chooser: &chooser)
                let previousDisplayPot = state.displayPot

                let applied = state.apply(action, by: actor, now: fixedNow)
                #expect(applied)
                #expect(state.displayPot >= previousDisplayPot || state.isHandComplete)

                handActions += 1
                #expect(handActions < 150)
                if handActions >= 150 { break }
            }

            assertStressInvariants(state, chipTotal: chipTotal)
            #expect(state.isHandComplete)
            completedHands += 1

            guard let next = state.startNextHand(seed: chooser.next(), now: fixedNow) else {
                break
            }
            state = next
        }

        #expect(completedHands >= 2)
        #expect(totalChips(state) == chipTotal)
    }

    @Test("mixed gameplay survives encoded operation envelopes across many hands")
    func mixedGameplaySurvivesEncodedOperationEnvelopesAcrossManyHands() throws {
        let fixedNow = Date(timeIntervalSince1970: 1_800_000_200)
        var chooser = DeterministicChooser(seed: 0x1234ABCD)
        var message = TableMessage.game(GameState.startHand(
            players: [
                Player(id: "alice", name: "Alice", avatar: "A", stack: 20_000),
                Player(id: "bob", name: "Bob", avatar: "B", stack: 20_000),
                Player(id: "cara", name: "Cara", avatar: "C", stack: 20_000),
                Player(id: "drew", name: "Drew", avatar: "D", stack: 20_000),
                Player(id: "erin", name: "Erin", avatar: "E", stack: 20_000),
                Player(id: "finn", name: "Finn", avatar: "F", stack: 20_000),
            ],
            dealerIndex: 1,
            smallBlind: 10,
            bigBlind: 20,
            seed: chooser.next(),
            handNumber: 1,
            tableID: "stress-table",
            now: fixedNow
        ))
        let initialState = try #require(message.gameState)
        let chipTotal = totalChips(initialState)
        var operationNumber = 0
        var completedHands = 0

        while completedHands < 40 {
            while let state = message.gameState, let actor = state.currentToAct {
                assertStressInvariants(state, chipTotal: chipTotal)
                let legal = state.legalActions(for: actor)
                let action = chooseAction(from: legal, chooser: &chooser)
                operationNumber += 1

                guard case .applied(let nextMessage) = try message.committing(
                    .gameAction(action),
                    actorID: state.players[actor].id,
                    operationID: "stress-action-\(operationNumber)",
                    now: fixedNow
                ) else {
                    Issue.record("expected encoded game action to apply")
                    return
                }

                message = nextMessage
                if let nextState = message.gameState {
                    assertStressInvariants(nextState, chipTotal: chipTotal)
                }
            }

            let completed = try #require(message.gameState)
            assertStressInvariants(completed, chipTotal: chipTotal)
            #expect(completed.isHandComplete)
            completedHands += 1

            guard completedHands < 40,
                  let actor = completed.presentPlayers.first,
                  completed.fundedPlayerCount >= 2 else {
                break
            }

            operationNumber += 1
            guard case .applied(let nextMessage) = try message.committing(
                .dealNextHand(seed: chooser.next()),
                actorID: actor.id,
                operationID: "stress-deal-\(operationNumber)",
                now: fixedNow
            ) else {
                Issue.record("expected encoded next-hand deal to apply")
                return
            }

            message = nextMessage
            if let nextState = message.gameState {
                assertStressInvariants(nextState, chipTotal: chipTotal)
            }
        }

        #expect(completedHands >= 10)
        #expect(operationNumber >= 80)
    }
}

private func assertStressInvariants(_ state: GameState, chipTotal: Int) {
    #expect(totalChips(state) == chipTotal)
    #expect(state.displayPot >= 0)
    #expect(state.board.count <= 5)
    #expect(state.players.allSatisfy { player in
        player.stack >= 0 &&
        player.bet >= 0 &&
        player.committed >= 0 &&
        player.holeCards.count <= 2
    })

    let visibleAndDeckCards = state.board + state.deck + state.players.flatMap(\.holeCards)
    #expect(Set(visibleAndDeckCards).count == visibleAndDeckCards.count)

    if state.isHandComplete {
        #expect(state.currentToAct == nil)
        #expect(state.pot == 0)
        #expect(state.currentBet == 0)
        #expect(state.players.allSatisfy { $0.bet == 0 })
        #expect(state.results != nil)
    } else if let currentToAct = state.currentToAct {
        #expect(state.players.indices.contains(currentToAct))
        #expect(state.players[currentToAct].canAct)

        let legal = state.legalActions(for: currentToAct)
        #expect(legal != .empty)
        #expect(legal.canCheck || legal.canCall)
        #expect(legal.callAmount >= 0)
        #expect(legal.currentBet == state.currentBet)
        if legal.canRaise {
            #expect(legal.minRaiseTo <= legal.maxRaiseTo)
            #expect(legal.maxRaiseTo > legal.currentBet)
        }
    } else {
        #expect(Bool(false), "live hands should always have a current actor")
    }
}

private extension TableMessage {
    var gameState: GameState? {
        guard case .game(let state) = self else { return nil }
        return state
    }
}

private func chooseAction(from legal: LegalActions, chooser: inout DeterministicChooser) -> PlayerAction {
    let roll = chooser.nextInt(100)

    if legal.canRaise && (roll < 10 || (legal.canCheck && roll < 14)) {
        return .raise(to: chooseRaiseTotal(from: legal, chooser: &chooser))
    }

    if legal.canCall {
        return legal.canFold && roll >= 96 ? .fold : .call
    }

    return .check
}

private func chooseAllInBiasedAction(from legal: LegalActions, chooser: inout DeterministicChooser) -> PlayerAction {
    let roll = chooser.nextInt(100)

    if legal.canRaise && roll < 42 {
        return .raise(to: roll < 24 ? legal.maxRaiseTo : chooseRaiseTotal(from: legal, chooser: &chooser))
    }

    if legal.canCall {
        return legal.canFold && roll >= 94 ? .fold : .call
    }

    return legal.canRaise && roll < 12 ? .raise(to: legal.maxRaiseTo) : .check
}

private func chooseRaiseTotal(from legal: LegalActions, chooser: inout DeterministicChooser) -> Int {
    let span = max(0, legal.maxRaiseTo - legal.minRaiseTo)
    guard span > 0 else { return legal.minRaiseTo }

    switch chooser.nextInt(5) {
    case 0:
        return legal.minRaiseTo
    case 1:
        return legal.minRaiseTo + span / 3
    case 2 where span <= legal.currentBet * 2:
        return legal.maxRaiseTo
    default:
        return min(legal.maxRaiseTo, legal.minRaiseTo + max(legal.currentBet, 1))
    }
}

private struct DeterministicChooser {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }

    mutating func nextInt(_ upperBound: Int) -> Int {
        Int(next() % UInt64(upperBound))
    }
}
