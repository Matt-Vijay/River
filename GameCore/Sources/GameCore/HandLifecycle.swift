import Foundation

extension GameState {
    /// Deals a fresh hand. Players with chips are dealt in; busted players sit out.
    static func startHand(
        players input: [Player],
        dealerIndex: Int,
        smallBlind: Int,
        bigBlind: Int,
        seed: UInt64,
        handNumber: Int,
        tableID: String = UUID().uuidString,
        turnDuration: TimeInterval = TurnClock.defaultDuration,
        now: Date = Date()
    ) -> GameState {
        let blinds = TableRules.normalizedBlinds(smallBlind: smallBlind, bigBlind: bigBlind)
        var players = Identity.uniquePlayers(Array(input.prefix(TableRules.maxPlayers)))
        for index in players.indices {
            players[index].bet = 0
            players[index].committed = 0
            players[index].holeCards = []
            players[index].lastActionBet = nil
            players[index].lastAction = nil
            players[index].status = players[index].isEligibleForNextHand
                ? .active : players[index].hasLeft ? .sittingOut : .eliminated
        }

        var state = GameState(
            tableID: Identity.normalized(tableID),
            handNumber: max(1, handNumber),
            players: players,
            dealerIndex: normalizedSeat(dealerIndex, playerCount: players.count),
            smallBlind: blinds.smallBlind,
            bigBlind: blinds.bigBlind,
            board: [],
            deck: Card.shuffledDeck(seed: seed),
            street: .preflop,
            currentToAct: nil,
            minRaise: blinds.bigBlind,
            turnStartedAt: nil,
            turnDuration: TurnClock.normalized(turnDuration),
            results: nil,
            version: 0
        )

        state.dealerIndex = state.nextSeat(after: state.dealerIndex - 1) { $0.canAct }
            ?? state.dealerIndex
        let dealOrder = players.indices.filter { players[$0].canAct }
            .sorted { state.seatOrder($0) < state.seatOrder($1) }
        // Two rounds left of the dealer. A fresh 52-card deck always covers six seats.
        for _ in 0..<2 {
            for seat in dealOrder {
                state.players[seat].holeCards.append(state.deck.removeFirst())
            }
        }
        state.openFirstBettingRound(now: now)
        return state
    }

    mutating func openFirstBettingRound(now: Date) {
        let playingCount = players.lazy.filter(\.canAct).count
        let smallBlindSeat = playingCount == 2
            ? dealerIndex : nextSeat(after: dealerIndex) { $0.canAct }
        let bigBlindSeat = smallBlindSeat.flatMap { nextSeat(after: $0) { $0.canAct } }
        let firstToAct = playingCount == 2
            ? smallBlindSeat : bigBlindSeat.flatMap { nextSeat(after: $0) { $0.canAct } }

        if let smallBlindSeat {
            pay(smallBlindSeat, additional: smallBlind)
        }
        if let bigBlindSeat {
            pay(bigBlindSeat, additional: bigBlind)
        }
        currentToAct = firstToAct.flatMap { firstToAct in
            players[firstToAct].canAct
                ? firstToAct
                : nextSeat(after: firstToAct) { $0.canAct }
        }
        turnStartedAt = currentToAct == nil ? nil : now

        if players.lazy.filter(\.canAct).count <= 1 {
            advance(now: now)
        }
    }

    mutating func advance(now: Date) {
        guard !isHandComplete else { return }
        if contenders.count <= 1 {
            awardUncontested()
            return
        }

        let actable = players.indices.filter { players[$0].canAct }
        let everyoneMatched = actable.allSatisfy {
            players[$0].bet == currentBet
                && (players[$0].lastActionBet == currentBet || actable.count == 1)
        }

        if !everyoneMatched {
            if let next = nextSeat(after: currentToAct ?? dealerIndex, where: { $0.canAct }) {
                currentToAct = next
                turnStartedAt = now
            }
            return
        }

        collectBets()

        if actable.count <= 1 {
            runOutAndShowdown()
            return
        }

        guard street != .river else {
            finishHand(ranks: showdownRanks())
            return
        }

        advanceStreet(now: now)
    }

    private mutating func advanceStreet(now: Date) {
        switch street {
        case .preflop:
            street = .flop
            board.append(contentsOf: deck.dealTopIfAvailable(3))
        case .flop, .turn:
            street = street == .flop ? .turn : .river
            if let card = deck.dealTopIfAvailable() { board.append(card) }
        case .river, .showdown:
            finishHand(ranks: showdownRanks())
            return
        }
        currentToAct = dealerSeatIndex.flatMap { nextSeat(after: $0) { $0.canAct } }
        turnStartedAt = now
    }

    func startNextHand(seed: UInt64, now: Date = Date()) -> GameState? {
        guard isHandComplete else { return nil }
        guard let nextHandNumber = MonotonicCounter.successor(of: handNumber),
              let nextVersion = MonotonicCounter.successor(of: version) else { return nil }
        let eligibleOriginalIndices = players.indices.filter { players[$0].isEligibleForNextHand }
        guard eligibleOriginalIndices.count >= 2 else { return nil }

        guard let nextDealer = nextDealerOriginalIndex(in: eligibleOriginalIndices),
              let dealer = eligibleOriginalIndices.firstIndex(of: nextDealer) else {
            return nil
        }

        var next = GameState.startHand(
            players: eligibleOriginalIndices.map { players[$0] },
            dealerIndex: dealer,
            smallBlind: smallBlind,
            bigBlind: bigBlind,
            seed: seed,
            handNumber: nextHandNumber,
            tableID: tableID,
            turnDuration: turnDuration,
            now: now
        )
        next.version = nextVersion
        return next
    }

    private func nextDealerOriginalIndex(in eligible: [Int]) -> Int? {
        // On the transition to heads-up, the button may need to move out of
        // the ordinary sequence so the prior big blind is not big blind twice.
        // Making that player the button preserves alternating blinds.
        if eligible.count == 2,
           let priorBigBlind = priorBigBlindOriginalIndex(),
           eligible.contains(priorBigBlind) {
            return priorBigBlind
        }
        return nextSeat(after: dealerIndex) { $0.isEligibleForNextHand }
    }

    private func priorBigBlindOriginalIndex() -> Int? {
        let dealtInCount = players.filter { $0.holeCards.count == 2 }.count
        guard dealtInCount >= 2,
              let first = nextSeat(after: dealerIndex, where: { $0.holeCards.count == 2 }) else {
            return nil
        }
        return dealtInCount == 2 ? first : nextSeat(after: first) { $0.holeCards.count == 2 }
    }
}

extension GameState {
    // MARK: - Resolving the hand

    private mutating func collectBets() {
        for index in players.indices {
            players[index].bet = 0
            players[index].lastActionBet = nil
        }
        minRaise = bigBlind
    }

    private mutating func runOutAndShowdown() {
        while board.count < 5, let card = deck.dealTopIfAvailable() {
            board.append(card)
        }
        finishHand(ranks: showdownRanks())
    }

    mutating func awardUncontested() {
        collectBets()
        guard players.contains(where: \.isContesting) else { return }
        finishHand(ranks: [:])
    }

    private mutating func finishHand(ranks: [Int: HandRank]) {
        let settlement = settlement(ranks: ranks)
        for index in players.indices {
            players[index].stack = TableRules.adding(
                players[index].stack,
                settlement.credits[players[index].id] ?? 0,
                limit: TableRules.tableMaximum
            )
        }
        results = showdownResults(ranks: ranks, winnings: settlement.winnings)
        currentToAct = nil
        street = .showdown
        minRaise = 0
        turnStartedAt = nil
    }

    func settlement(ranks: [Int: HandRank]) -> (
        credits: [String: Int], winnings: [String: Int], refundedTotal: Int
    ) {
        var credits: [String: Int] = [:]
        var winnings: [String: Int] = [:]
        var refundedTotal = 0
        let levels = Set(players.map(\.committed).filter { $0 > 0 }).sorted()
        var previous = 0
        for level in levels {
            let contributors = players.indices.filter { players[$0].committed >= level }
            let product = (level - previous).multipliedReportingOverflow(
                by: contributors.count
            )
            let amount = product.overflow
                ? TableRules.tableMaximum
                : TableRules.table(product.partialValue)
            let eligible = contributors.filter { players[$0].isContesting }
            // A contribution no opponent matched is not a pot. Return that
            // layer without presenting it as money won at showdown.
            let winners = contributors.count == 1
                ? nil
                : winners(among: eligible, ranks: ranks)
            for (seat, award) in split(amount, among: winners ?? contributors) {
                let playerID = players[seat].id
                credits[playerID] = TableRules.adding(
                    credits[playerID] ?? 0, award, limit: TableRules.tableMaximum)
                if winners != nil {
                    winnings[playerID] = TableRules.adding(
                        winnings[playerID] ?? 0, award, limit: TableRules.tableMaximum)
                } else {
                    refundedTotal = TableRules.adding(
                        refundedTotal, award, limit: TableRules.tableMaximum)
                }
            }
            previous = level
        }
        return (credits, winnings, refundedTotal)
    }

    private func winners(among eligible: [Int], ranks: [Int: HandRank]) -> [Int]? {
        guard eligible.count > 1 else { return eligible.isEmpty ? nil : eligible }
        let ranked = eligible.compactMap { index in
            ranks[index].map { (index: index, rank: $0) }
        }
        guard ranked.count == eligible.count, let best = ranked.map(\.rank).max() else {
            return nil
        }
        return ranked.filter { $0.rank == best }.map(\.index)
    }

    private func split(_ total: Int, among seats: [Int]) -> [(seat: Int, amount: Int)] {
        guard !seats.isEmpty else { return [] }
        let share = total / seats.count
        let remainder = total % seats.count
        return seats.sorted(by: { seatOrder($0) < seatOrder($1) })
            .enumerated()
            .map { offset, seat in (seat, share + (offset < remainder ? 1 : 0)) }
    }

    func seatOrder(_ index: Int) -> Int {
        guard let dealerSeatIndex else { return 0 }
        return Self.normalizedSeat(index - dealerSeatIndex - 1, playerCount: players.count)
    }

    func showdownRanks() -> [Int: HandRank] {
        var ranks: [Int: HandRank] = [:]
        for index in players.indices where players[index].isContesting {
            ranks[index] = HandEvaluator.evaluateIfPossible(players[index].holeCards + board)
        }
        return ranks
    }

    func showdownResults(ranks: [Int: HandRank], winnings: [String: Int]) -> [HandResult] {
        players.indices.compactMap { index in
            guard let amount = winnings[players[index].id],
                  amount > 0 else { return nil }
            return HandResult(
                playerID: players[index].id,
                amountWon: amount,
                handName: ranks[index]?.name,
                bestFive: ranks[index]?.bestFive
            )
        }
    }
}
