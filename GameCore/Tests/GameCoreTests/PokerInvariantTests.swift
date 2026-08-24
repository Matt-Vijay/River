import Foundation
import Testing

@testable import GameCore

@Suite("Seeded poker invariants")
struct PokerInvariantTests {
    @Test("legal seeded tournaments preserve the card, chip, actor, and revision ledgers")
    func seededTournamentInvariants() throws {
        var aggregate = InvariantCoverage()

        for playerCount in 2...6 {
            for variation in 0..<4 {
                let scenario = TournamentScenario(
                    playerCount: playerCount,
                    variation: variation
                )
                let outcome = try playTournament(scenario)
                aggregate.merge(outcome.coverage)

                #expect(outcome.coverage.completedHands > 0)
                #expect(outcome.coverage.acceptedActions > 0)
                #expect(outcome.finalState.isHandComplete)
            }
        }

        // These are coverage sentinels, not statistical assertions: fixed seeds make
        // every one deterministic and ensure the exercise does not silently decay
        // into a check/call-only smoke test.
        #expect(aggregate.acceptedActions > 200)
        #expect(aggregate.raises > 0)
        #expect(aggregate.folds > 0)
        #expect(aggregate.allInActions > 0)
        #expect(aggregate.showdowns > 0)
        #expect(aggregate.foldedContributions > 0)
        #expect(aggregate.sidePotLayouts > 0)
        #expect(aggregate.nextHands > 0)
    }

    @Test("identical deal and policy seeds replay to the identical terminal state")
    func deterministicReplay() throws {
        for playerCount in [2, 4, 6] {
            let scenario = TournamentScenario(playerCount: playerCount, variation: 7)
            let first = try playTournament(scenario)
            let replay = try playTournament(scenario)

            #expect(replay.finalState == first.finalState)
            #expect(replay.actions == first.actions)
            #expect(replay.coverage == first.coverage)
            #expect(replay.finalPayload == first.finalPayload)
        }
    }
}

private struct TournamentScenario {
    let playerCount: Int
    let variation: Int

    var dealSeed: UInt64 {
        UInt64(playerCount * 10_000 + variation * 101 + 17)
    }

    var policySeed: UInt64 {
        dealSeed ^ 0xA11C_E5ED_F00D_BAAD
    }

    var tableID: String {
        "invariant-\(playerCount)-\(variation)"
    }

    var stacks: [Int] {
        let palette = [13, 21, 34, 55, 89, 144]
        return (0..<playerCount).map { seat in
            palette[(seat + variation) % palette.count] + (variation % 3)
        }
    }
}

private struct TournamentOutcome {
    let finalState: GameState
    let finalPayload: String
    let actions: [PlayerAction]
    let coverage: InvariantCoverage
}

private struct InvariantCoverage: Equatable {
    var acceptedActions = 0
    var raises = 0
    var folds = 0
    var allInActions = 0
    var completedHands = 0
    var showdowns = 0
    var foldedContributions = 0
    var sidePotLayouts = 0
    var nextHands = 0

    mutating func merge(_ other: Self) {
        acceptedActions += other.acceptedActions
        raises += other.raises
        folds += other.folds
        allInActions += other.allInActions
        completedHands += other.completedHands
        showdowns += other.showdowns
        foldedContributions += other.foldedContributions
        sidePotLayouts += other.sidePotLayouts
        nextHands += other.nextHands
    }
}

private func playTournament(_ scenario: TournamentScenario) throws -> TournamentOutcome {
    let players = scenario.stacks.enumerated().map { seat, stack in
        Player(
            id: "p\(seat)",
            name: "Player \(seat)",
            avatar: "\(seat + 1)",
            stack: stack
        )
    }
    let initialChipTotal = players.reduce(0) { $0 + $1.stack }
    let baseDate = Date(timeIntervalSince1970: 1_800_000_000)
    var state = GameState.startHand(
        players: players,
        dealerIndex: scenario.variation - scenario.playerCount,
        smallBlind: 5,
        bigBlind: 10,
        seed: scenario.dealSeed,
        handNumber: 1,
        tableID: scenario.tableID,
        turnDuration: 300,
        now: baseDate
    )
    var policy = InvariantGenerator(seed: scenario.policySeed)
    var actions: [PlayerAction] = []
    var coverage = InvariantCoverage()
    var operationNumber = 0
    var actionsThisHand = 0

    state = try roundTripped(state)
    assertStateInvariants(state, chipTotal: initialChipTotal)

    while coverage.completedHands < 10 {
        if state.isHandComplete {
            coverage.completedHands += 1
            if state.board.count == 5, state.contenders.count > 1 {
                coverage.showdowns += 1
            }
            if state.players.contains(where: { $0.status == .folded && $0.committed > 0 }) {
                coverage.foldedContributions += 1
            }
            if Set(state.players.map(\.committed).filter { $0 > 0 }).count > 1 {
                coverage.sidePotLayouts += 1
            }

            let eligible = state.players.indices.filter {
                state.players[$0].isEligibleForNextHand
            }
            guard eligible.count >= 2, coverage.completedHands < 10 else { break }

            let expectedDealerID = try #require(nextDealerID(in: state, eligible: eligible))
            let actorID = state.players[eligible[policy.index(upperBound: eligible.count)]].id
            let previous = state
            operationNumber += 1
            let result = TableMessage.game(state).committing(
                .dealNextHand(seed: policy.next()),
                actorID: actorID,
                now: baseDate.addingTimeInterval(TimeInterval(operationNumber))
            )
            let next = try appliedGame(result)

            #expect(next.version == previous.version + 1)
            #expect(next.handNumber == previous.handNumber + 1)
            #expect(next.tableID == previous.tableID)
            #expect(next.players.map(\.id) == eligible.map { previous.players[$0].id })
            #expect(next.players[next.dealerIndex].id == expectedDealerID)

            state = try roundTripped(next)
            coverage.nextHands += 1
            actionsThisHand = 0
            assertStateInvariants(state, chipTotal: initialChipTotal)
            continue
        }

        actionsThisHand += 1
        #expect(actionsThisHand <= 256)
        guard actionsThisHand <= 256 else { break }

        let actorIndex = try #require(state.currentToAct)
        let actorID = state.players[actorIndex].id
        let legal = state.legalActions(for: actorIndex)
        let action = policy.action(from: legal)
        #expect(legal.allows(action))

        let previous = state
        operationNumber += 1
        let result = TableMessage.game(state).committing(
            .gameAction(action),
            actorID: actorID,
            now: baseDate.addingTimeInterval(TimeInterval(operationNumber))
        )
        let next = try appliedGame(result)

        #expect(next.version == previous.version + 1)
        #expect(next.tableID == previous.tableID)
        #expect(next.handNumber == previous.handNumber)
        #expect(next.players.map(\.id) == previous.players.map(\.id))

        coverage.acceptedActions += 1
        actions.append(action)
        switch action {
        case .raise: coverage.raises += 1
        case .fold: coverage.folds += 1
        case .check, .call: break
        }
        if next.players[actorIndex].stack == 0,
           previous.players[actorIndex].stack > 0 {
            coverage.allInActions += 1
        }

        state = try roundTripped(next)
        assertStateInvariants(state, chipTotal: initialChipTotal)
    }

    #expect(state.isHandComplete)
    let finalPayload = try GamePayload.encode(.game(state))
    return TournamentOutcome(
        finalState: state,
        finalPayload: finalPayload,
        actions: actions,
        coverage: coverage
    )
}

private func appliedGame(_ result: TableOperationResult) throws -> GameState {
    guard case .applied(.game(let state)) = result else {
        Issue.record("A generated legal operation was unexpectedly rejected: \(result)")
        throw InvariantFailure.operationRejected
    }
    return state
}

private func roundTripped(_ state: GameState) throws -> GameState {
    let message = TableMessage.game(state)
    let payload = try GamePayload.encode(message)
    let decoded = try GamePayload.decodeMessage(from: payload)

    #expect(decoded == message)
    #expect(decoded.revision == message.revision)
    #expect(decoded.revision.tableID == state.tableID)

    guard case .game(let decodedState) = decoded else {
        throw InvariantFailure.wrongPayloadPhase
    }
    return decodedState
}

private func assertStateInvariants(_ state: GameState, chipTotal: Int) {
    let ownedCards = state.players.flatMap(\.holeCards) + state.board + state.deck
    let committed = state.players.reduce(0) { $0 + $1.committed }
    let stacks = state.players.reduce(0) { $0 + $1.stack }

    #expect(ownedCards.count == 52)
    #expect(Set(ownedCards).count == 52)
    #expect(Set(ownedCards) == Set(Card.fullDeck))
    #expect(Set(state.players.map(\.id)).count == state.players.count)
    #expect(state.players.allSatisfy { player in
        player.stack >= 0 && player.bet >= 0 && player.committed >= player.bet
    })
    #expect(state.players.allSatisfy { !$0.canAct || $0.stack > 0 })
    #expect(state.players.allSatisfy { !$0.hasLeft || !$0.canAct })

    if state.isHandComplete {
        #expect(stacks == chipTotal)
        #expect(state.currentToAct == nil)
        #expect(state.turnStartedAt == nil)
        #expect(state.street == .showdown)
        #expect(state.players.allSatisfy { $0.bet == 0 })
        #expect(state.players.indices.allSatisfy {
            state.legalActions(for: $0) == .empty
        })
        #expect(state.results?.isEmpty == false)
        #expect(state.contenders.count >= 1)
        if state.contenders.count > 1 {
            #expect(state.board.count == 5)
            #expect(state.contenders.allSatisfy { $0.holeCards.count == 2 })
        }
        return
    }

    #expect(stacks + committed == chipTotal)
    #expect(state.displayPot == committed)
    #expect(state.street != .showdown)
    #expect(state.board.count == state.street.boardCount)
    #expect(state.minRaise >= state.bigBlind)
    #expect(state.contenders.count >= 2)
    #expect(state.contenders.allSatisfy { $0.holeCards.count == 2 })
    #expect(state.players.allSatisfy { $0.status != .allIn || $0.stack == 0 })

    guard let actorIndex = state.currentToAct,
          state.players.indices.contains(actorIndex) else {
        Issue.record("A live hand has no in-range actor")
        return
    }
    let actor = state.players[actorIndex]
    let legal = state.legalActions(for: actorIndex)
    let expectedCall = min(max(0, state.currentBet - actor.bet), actor.stack)

    #expect(actor.canAct)
    #expect(actor.stack > 0)
    #expect(state.turnStartedAt != nil)
    #expect(legal.canFold)
    #expect(legal.currentBet == state.currentBet)
    #expect(legal.callAmount == expectedCall)
    #expect(legal.canCheck == (expectedCall == 0))
    #expect(legal.canCall == (expectedCall > 0))
    #expect(state.players.indices.filter { $0 != actorIndex }.allSatisfy {
        state.legalActions(for: $0) == .empty
    })

    if let bounds = legal.raiseBounds {
        #expect(bounds.lowerBound <= bounds.upperBound)
        #expect(bounds.lowerBound > state.currentBet)
        #expect(bounds.upperBound == actor.bet + actor.stack)
        #expect(bounds.lowerBound == min(
            state.currentBet + state.minRaise,
            bounds.upperBound
        ))
        #expect(legal.allows(.raise(to: bounds.lowerBound)))
        #expect(legal.allows(.raise(to: bounds.upperBound)))
        #expect(!legal.allows(.raise(to: bounds.lowerBound - 1)))
    }
}

private func nextDealerID(in state: GameState, eligible: [Int]) -> String? {
    guard !state.players.isEmpty else { return nil }
    let eligible = Set(eligible)
    let dealer = GameState.normalizedSeat(
        state.dealerIndex,
        playerCount: state.players.count
    )

    // When a table contracts to heads-up, the prior big blind gets the button
    // if still seated. That prevents one player from posting the big blind in
    // consecutive hands. Otherwise the button advances normally.
    let dealtIn = Set(state.players.indices.filter {
        state.players[$0].holeCards.count == 2
    })
    if eligible.count == 2,
       let priorBigBlind = priorBigBlind(
           dealer: dealer,
           dealtIn: dealtIn,
           playerCount: state.players.count
       ),
       eligible.contains(priorBigBlind) {
        return state.players[priorBigBlind].id
    }

    for offset in 1...state.players.count {
        let candidate = (dealer + offset) % state.players.count
        if eligible.contains(candidate) { return state.players[candidate].id }
    }
    return nil
}

private func priorBigBlind(
    dealer: Int,
    dealtIn: Set<Int>,
    playerCount: Int
) -> Int? {
    guard dealtIn.count >= 2 else { return nil }
    let firstAfterDealer = nextSeat(
        after: dealer,
        among: dealtIn,
        playerCount: playerCount
    )
    if dealtIn.count == 2 { return firstAfterDealer }
    return firstAfterDealer.flatMap {
        nextSeat(after: $0, among: dealtIn, playerCount: playerCount)
    }
}

private func nextSeat(
    after seat: Int,
    among seats: Set<Int>,
    playerCount: Int
) -> Int? {
    guard playerCount > 0 else { return nil }
    for offset in 1...playerCount {
        let candidate = (seat + offset) % playerCount
        if seats.contains(candidate) { return candidate }
    }
    return nil
}

private struct InvariantGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }

    mutating func index(upperBound: Int) -> Int {
        precondition(upperBound > 0)
        return Int(next() % UInt64(upperBound))
    }

    mutating func action(from legal: LegalActions) -> PlayerAction {
        let roll = index(upperBound: 100)
        if let bounds = legal.raiseBounds, roll < 52 {
            switch roll % 3 {
            case 0:
                return .raise(to: bounds.lowerBound)
            case 1:
                return .raise(to: bounds.upperBound)
            default:
                let width = bounds.upperBound - bounds.lowerBound
                let offset = width == 0 ? 0 : index(upperBound: width + 1)
                return .raise(to: bounds.lowerBound + offset)
            }
        }
        if roll >= 90 { return .fold }
        return legal.canCheck ? .check : .call
    }
}

private enum InvariantFailure: Error {
    case operationRejected
    case wrongPayloadPhase
}
