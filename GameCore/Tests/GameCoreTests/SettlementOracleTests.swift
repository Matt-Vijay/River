import Foundation
import Testing

@testable import GameCore

@Suite("Independent settlement oracle")
struct SettlementOracleTests {
    @Test("terminal stacks and reported winnings agree across the settlement matrix")
    func deterministicSettlementMatrix() {
        let matrix = SettlementScenario.matrix

        #expect(matrix.count == 80)
        for playerCount in 2...6 {
            let cases = matrix.filter { $0.commitments.count == playerCount }
            #expect(cases.count == playerCount * SettlementFamily.allCases.count)
            #expect(Set(cases.map(\.normalizedDealer)) == Set(0..<playerCount))
        }

        var casesWithRefunds = 0
        var casesWithOddChips = 0
        var casesWithFoldedContributions = 0

        for scenario in matrix {
            let oracle = ReferenceSettlement(scenario: scenario)
            let first = scenario.productionResult()
            let replay = scenario.productionResult()
            let expectedStacks = zip(scenario.baseStacks, oracle.credits).map(+)
            let expectedWinnings = Dictionary(uniqueKeysWithValues:
                oracle.winnings.enumerated().compactMap { seat, amount in
                    amount > 0 ? ("p\(seat)", amount) : nil
                }
            )
            let actualWinnings = Dictionary(uniqueKeysWithValues:
                (first.results ?? []).map { ($0.playerID, $0.amountWon) }
            )
            let actualStackTotal = first.players.map(\.stack).reduce(0, +)
            let initialStackTotal = scenario.baseStacks.reduce(0, +)
            let committedTotal = scenario.commitments.reduce(0, +)
            let reportedWinningsTotal = oracle.winnings.reduce(0, +)
            let evidence = scenario.evidence

            #expect(first == replay, "non-deterministic replay: \(evidence)")
            #expect(first.isHandComplete, "hand did not complete: \(evidence)")
            #expect(first.street == .showdown, "wrong terminal street: \(evidence)")
            #expect(first.currentToAct == nil, "terminal actor remained: \(evidence)")
            #expect(first.players.map(\.stack) == expectedStacks,
                    "stack/oracle mismatch: \(evidence)")
            #expect(actualWinnings == expectedWinnings,
                    "result/oracle mismatch: \(evidence)")
            #expect(first.results?.count == expectedWinnings.count,
                    "duplicate or zero-value result: \(evidence)")
            #expect(first.displayPot == reportedWinningsTotal,
                    "displayed winnings include a refund: \(evidence)")
            #expect(actualStackTotal == initialStackTotal + committedTotal,
                    "chip conservation failed: \(evidence)")
            #expect(reportedWinningsTotal + oracle.refundedTotal == committedTotal,
                    "oracle conservation failed: \(evidence)")

            casesWithRefunds += oracle.refundedTotal > 0 ? 1 : 0
            casesWithOddChips += oracle.oddChipLayers > 0 ? 1 : 0
            casesWithFoldedContributions += scenario.folded.isEmpty ? 0 : 1
        }

        // Fixed coverage sentinels keep this a side-pot matrix rather than a
        // check/call or evaluator fuzz suite.
        #expect(casesWithRefunds == 52)
        #expect(casesWithOddChips == 33)
        #expect(casesWithFoldedContributions == 76)
    }
}

private enum SettlementFamily: String, CaseIterable {
    case rankedUnequal
    case tiedOddMain
    case tiedSidePots
    case foldedTopRefund
}

private struct SettlementScenario {
    let family: SettlementFamily
    let commitments: [Int]
    let folded: Set<Int>
    /// A deliberately simple, test-owned ordering: larger values win and equal
    /// values tie. Card fixtures below are chosen to realize this ordering.
    let strengths: [Int]
    let dealer: Int
    let board: String
    let hands: [String]

    var normalizedDealer: Int {
        ((dealer % commitments.count) + commitments.count) % commitments.count
    }

    var baseStacks: [Int] {
        commitments.indices.map { folded.contains($0) ? 100 + $0 : 0 }
    }

    var evidence: String {
        "family=\(family.rawValue), players=\(commitments.count), "
            + "dealer=\(dealer)->\(normalizedDealer), commitments=\(commitments), "
            + "folded=\(folded.sorted()), strengths=\(strengths)"
    }

    func productionResult() -> GameState {
        var players = makePlayers(baseStacks)
        for seat in players.indices {
            players[seat].committed = commitments[seat]
            players[seat].status = folded.contains(seat) ? .folded : .allIn
            players[seat].holeCards = cards(hands[seat])
        }

        var state = GameState(
            tableID: "settlement-oracle-\(commitments.count)-\(family.rawValue)-\(dealer)",
            handNumber: 1,
            players: players,
            dealerIndex: dealer,
            smallBlind: 1,
            bigBlind: 2,
            board: cards(board),
            deck: [],
            street: .river,
            currentToAct: nil,
            minRaise: 2,
            turnStartedAt: nil,
            turnDuration: 30,
            results: nil,
            version: 0
        )
        state.advance(now: .distantPast)
        return state
    }

    static let matrix: [SettlementScenario] = {
        let rankedHands = [
            "As Ad", "Ks Kd", "Qs Qd", "Ts Td", "8s 8d", "6s 6d",
        ]
        let tiedHands = [
            "2c 2d", "3c 3d", "4c 4d", "5c 5d", "6c 6d", "7c 7d",
        ]
        let rankedCommitments = [3, 7, 12, 18, 25, 33]
        let tiedCommitments = [2, 5, 5, 8, 8, 13]
        let foldedTopCommitments = [4, 9, 15, 22, 30, 39]
        var scenarios: [SettlementScenario] = []

        for playerCount in 2...6 {
            let rankedStrengths = (0..<playerCount).map { playerCount - $0 }
            let tiedStrengths = Array(repeating: 1, count: playerCount)
            let rankedFolded: Set<Int> = playerCount > 2 ? [1] : []
            let oddFolded: Set<Int> = [playerCount == 2 ? 1 : playerCount / 2]
            var tiedSidePotFolded: Set<Int> = playerCount > 2 ? [1] : []
            if playerCount >= 5 { tiedSidePotFolded.insert(playerCount - 2) }

            for normalizedDealer in 0..<playerCount {
                scenarios.append(SettlementScenario(
                    family: .rankedUnequal,
                    commitments: Array(rankedCommitments.prefix(playerCount)),
                    folded: rankedFolded,
                    strengths: rankedStrengths,
                    dealer: normalizedDealer,
                    board: "2c 3d 7h 9s Jc",
                    hands: Array(rankedHands.prefix(playerCount))
                ))
                scenarios.append(SettlementScenario(
                    family: .tiedOddMain,
                    commitments: Array(repeating: 1, count: playerCount),
                    folded: oddFolded,
                    strengths: tiedStrengths,
                    dealer: normalizedDealer - playerCount,
                    board: "Ah Kh Qh Jh Th",
                    hands: Array(tiedHands.prefix(playerCount))
                ))
                scenarios.append(SettlementScenario(
                    family: .tiedSidePots,
                    commitments: Array(tiedCommitments.prefix(playerCount)),
                    folded: tiedSidePotFolded,
                    strengths: tiedStrengths,
                    dealer: normalizedDealer + 2 * playerCount,
                    board: "Ah Kh Qh Jh Th",
                    hands: Array(tiedHands.prefix(playerCount))
                ))
                scenarios.append(SettlementScenario(
                    family: .foldedTopRefund,
                    commitments: Array(foldedTopCommitments.prefix(playerCount)),
                    folded: [playerCount - 1],
                    strengths: rankedStrengths,
                    dealer: normalizedDealer,
                    board: "2c 3d 7h 9s Jc",
                    hands: Array(rankedHands.prefix(playerCount))
                ))
            }
        }
        return scenarios
    }()
}

/// A settlement model intentionally isolated from `GameState.settlement`,
/// `seatOrder`, and showdown result construction. It receives only plain seat
/// facts and independently derives contribution layers, refunds, winners, and
/// odd-chip priority.
private struct ReferenceSettlement {
    let credits: [Int]
    let winnings: [Int]
    let refundedTotal: Int
    let oddChipLayers: Int

    init(scenario: SettlementScenario) {
        let playerCount = scenario.commitments.count
        var credits = Array(repeating: 0, count: playerCount)
        var winnings = Array(repeating: 0, count: playerCount)
        var refundedTotal = 0
        var oddChipLayers = 0
        var lowerBound = 0

        for upperBound in Set(scenario.commitments).filter({ $0 > 0 }).sorted() {
            let contributors = scenario.commitments.indices.filter {
                scenario.commitments[$0] >= upperBound
            }
            let layerAmount = (upperBound - lowerBound) * contributors.count

            if contributors.count == 1 {
                let seat = contributors[0]
                credits[seat] += layerAmount
                refundedTotal += layerAmount
            } else {
                let eligible = contributors.filter { !scenario.folded.contains($0) }
                precondition(!eligible.isEmpty, "A matched layer needs a live claimant")
                let bestStrength = eligible.map { scenario.strengths[$0] }.max()!
                let winners = eligible.filter { scenario.strengths[$0] == bestStrength }
                let orderedWinners = winners.sorted {
                    oddChipDistance(from: scenario.dealer, to: $0, seats: playerCount)
                        < oddChipDistance(from: scenario.dealer, to: $1, seats: playerCount)
                }
                let equalShare = layerAmount / orderedWinners.count
                let remainder = layerAmount % orderedWinners.count
                oddChipLayers += remainder > 0 ? 1 : 0

                for (offset, seat) in orderedWinners.enumerated() {
                    let award = equalShare + (offset < remainder ? 1 : 0)
                    credits[seat] += award
                    winnings[seat] += award
                }
            }
            lowerBound = upperBound
        }

        self.credits = credits
        self.winnings = winnings
        self.refundedTotal = refundedTotal
        self.oddChipLayers = oddChipLayers
    }
}

private func oddChipDistance(from dealer: Int, to seat: Int, seats: Int) -> Int {
    let normalizedDealer = ((dealer % seats) + seats) % seats
    return ((seat - normalizedDealer - 1) % seats + seats) % seats
}
