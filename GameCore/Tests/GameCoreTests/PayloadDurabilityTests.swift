import Testing
import Foundation
@testable import GameCore

@Suite("Payload durability")
struct PayloadDurabilityTests {
    @Test("legacy action markers and accumulated stacks remain compatible")
    func legacyActionMarkersAndAccumulatedStacksRemainCompatible() throws {
        var state = GameState.startHand(players: [
            Player(id: "a", name: "a", avatar: "🙂", stack: 1000),
            Player(id: "b", name: "b", avatar: "🙂", stack: 1000),
        ], dealerIndex: 0, smallBlind: 10, bigBlind: 20, seed: 3, handNumber: 1)

        var actedPlayer = state.players[0]
        actedPlayer.lastActionBet = actedPlayer.bet
        var encodedPlayer = try #require(
            JSONSerialization.jsonObject(
                with: GamePayload.encoder.encode(actedPlayer)
            ) as? [String: Any]
        )
        encodedPlayer["hasActed"] = false
        #expect(throws: DecodingError.self) {
            _ = try GamePayload.decoder.decode(
                Player.self,
                from: JSONSerialization.data(withJSONObject: encodedPlayer)
            )
        }

        encodedPlayer.removeValue(forKey: "lastActionBet")
        encodedPlayer["hasActed"] = true
        let legacyWirePlayer = try GamePayload.decoder.decode(
            Player.self,
            from: JSONSerialization.data(withJSONObject: encodedPlayer)
        )
        #expect(legacyWirePlayer.lastActionBet == actedPlayer.bet)

        encodedPlayer.removeValue(forKey: "hasActed")
        #expect(throws: DecodingError.self) {
            _ = try GamePayload.decoder.decode(
                Player.self,
                from: JSONSerialization.data(withJSONObject: encodedPlayer)
            )
        }

        let accumulatedStack = TableRules.buyInMaximum + 1
        let matchedContribution = accumulatedStack / 2
        state.players[0].stack = accumulatedStack
        for index in state.players.indices {
            state.players[index].bet = 0
            state.players[index].committed = 0
            state.players[index].status = index == 0 ? .active : .folded
        }
        state.players[0].committed = matchedContribution
        state.players[1].committed = matchedContribution
        state.results = [
            HandResult(playerID: state.players[0].id, amountWon: accumulatedStack,
                       handName: nil, bestFive: nil),
        ]
        state.street = .showdown
        state.currentToAct = nil
        state.minRaise = 0
        state.turnStartedAt = nil

        let settledWire = try encodedGame(state)
        let settled = try decodedGame(from: settledWire)
        #expect(settled.players[0].stack == accumulatedStack)
        #expect(settled.results?.first?.amountWon == accumulatedStack)
    }

    @Test("equivalent best-five card choices remain wire compatible")
    func equivalentBestFiveChoicesRemainCompatible() throws {
        var state = GameState.startHand(
            players: makePlayers([1_000, 1_000]), dealerIndex: 0,
            smallBlind: 10, bigBlind: 20, seed: 1, handNumber: 1,
            tableID: "table-alternate-best-five"
        )
        state.players[0].holeCards = cards("Ah As")
        state.players[1].holeCards = cards("Kc Qc")
        state.board = cards("Ad Ac Kh Kd 2s")
        let visible = Set(state.players.flatMap(\.holeCards) + state.board)
        state.deck = Card.fullDeck.filter { !visible.contains($0) }
        for index in state.players.indices {
            state.players[index].bet = 0
            state.players[index].committed = 100
            state.players[index].lastActionBet = nil
            state.players[index].status = .active
            state.players[index].stack = index == 0 ? 1_100 : 900
        }
        state.street = .showdown
        state.currentToAct = nil
        state.minRaise = 0
        state.turnStartedAt = nil

        let rank = HandEvaluator.evaluate(state.players[0].holeCards + state.board)
        let canonicalKing = try #require(rank.bestFive.first { $0.rank == .king })
        let alternateKing = try #require(
            state.board.first { $0.rank == .king && $0 != canonicalKing }
        )
        var alternate = rank.bestFive
        alternate[try #require(alternate.firstIndex(of: canonicalKing))] = alternateKing
        #expect(Set(alternate) != Set(rank.bestFive))
        #expect(HandEvaluator.evaluate(alternate) == rank)

        state.results = [
            HandResult(
                playerID: state.players[0].id, amountWon: 200,
                handName: rank.name, bestFive: alternate
            ),
        ]

        let decoded = try decodedGame(from: encodedGame(state))
        #expect(decoded.results?.first?.bestFive == alternate)
    }

    @Test("payloads reject unrecoverable poker state")
    func payloadsRejectUnrecoverablePokerState() throws {
        let rejectedPayloads = try [
            corrupted { $0.deck = Array($0.deck.prefix(5)) },
            corrupted { state in
                state.deck.append(try #require(state.deck.first))
            },
            corrupted { $0.players[0].holeCards.append($0.deck.removeFirst()) },
            corrupted { state in
                let player = try #require(state.players.firstIndex { $0.committed > 0 })
                state.players[player].stack = Int.max
            },
            corrupted { $0.currentToAct = 99 },
            corrupted { state in
                let actor = try #require(state.players.firstIndex {
                    $0.canAct && $0.bet == state.currentBet
                })
                state.players[actor].lastActionBet = state.players[actor].bet
                state.currentToAct = actor
            },
            corrupted { $0.players[0].lastActionBet = $0.players[0].bet + 1 },
            corrupted { $0.turnStartedAt = nil },
            corrupted { $0.street = .river },
            corrupted { state in
                state.street = .showdown
                state.board = Array(state.deck.prefix(5))
            },
            corrupted { state in
                for index in state.players.indices.dropFirst() {
                    state.players[index].status = .folded
                }
            },
            corrupted { state in
                let actor = try #require(state.currentToAct)
                state.players[actor].stack = 0
                state.players[actor].status = .active
            },
            corrupted { state in
                let player = try #require(state.players.indices.first {
                    $0 != state.currentToAct && state.players[$0].stack > 0
                })
                state.players[player].status = .allIn
            },
            corrupted { state in
                let committed = state.players.reduce(0) { $0 + $1.committed }
                state.results = [result(in: state, amount: committed + 1)]
            },
            corrupted { state in state.results = [result(in: state, amount: 1)] },
            corrupted { state in
                let player = try #require(state.players.firstIndex { $0.committed > 0 })
                state.players[player].status = .folded
                state.results = [result(in: state, player: player,
                                        amount: state.players[player].committed)]
            },
            corrupted { state in
                for index in state.players.indices { state.players[index].committed = 0 }
                state.players[0].committed = 10
                state.players[1].committed = 100
                state.results = [result(in: state, amount: 110)]
            },
            corrupted { state in
                checkOrCallToShowdown(&state)
                var results = try #require(state.results)
                let winnerIDs = Set(results.map(\.playerID))
                let loser = try #require(state.players.first { !winnerIDs.contains($0.id) }?.id)
                results[0].playerID = loser
                state.results = results
            },
            corrupted { state in
                checkOrCallToShowdown(&state)
                state.results?[0].handName = "Royal Flush"
            },
            corrupted(try foldedHeadsUpState()) { $0.results?[0].handName = "Royal Flush" },
            corrupted(try foldedHeadsUpState()) { state in
                state.results?[0].bestFive = Array(state.deck.prefix(5))
            },
            corrupted { $0.results = [] },
            corrupted { state in state.results = [result(in: state, amount: 0)] },
        ].map(encodedGame)

        for payload in rejectedPayloads {
            #expect(throws: DecodingError.self) {
                _ = try decodedGame(from: payload)
            }
        }
    }

    private func corrupted(_ initial: GameState = sixPlayerState(),
                           mutate: (inout GameState) throws -> Void) rethrows -> GameState {
        var state = initial
        try mutate(&state)
        return state
    }

    private func result(in state: GameState, player: Int = 0,
                        amount: Int) -> HandResult {
        HandResult(playerID: state.players[player].id, amountWon: amount,
                   handName: nil, bestFive: nil)
    }

    private func foldedHeadsUpState() throws -> GameState {
        var state = GameState.startHand(players: makePlayers([1000, 1000]),
                                        dealerIndex: 0, smallBlind: 10, bigBlind: 20,
                                        seed: 7, handNumber: 1)
        let actor = try #require(state.currentToAct)
        let didFold = state.apply(.fold, by: actor)
        #expect(didFold)
        return state
    }
}
