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
        var players = preparedPlayersForNewHand(
            Identity.uniquePlayers(Array(input.prefix(TableRules.maxPlayers)))
        )
        let dealerIndex = activeDealerIndex(preferred: dealerIndex, players: players)
        var deck = Card.shuffledDeck(seed: seed)
        let dealOrder = dealOrder(players: players, dealerIndex: dealerIndex)
        dealHoleCards(to: &players, deck: &deck, dealOrder: dealOrder)

        var state = GameState(
            tableID: Identity.normalized(tableID),
            handNumber: max(1, handNumber),
            players: players,
            dealerIndex: dealerIndex,
            smallBlind: blinds.smallBlind,
            bigBlind: blinds.bigBlind,
            board: [],
            deck: deck,
            street: .preflop,
            currentToAct: nil,
            minRaise: blinds.bigBlind,
            turnStartedAt: nil,
            turnDuration: TurnClock.normalized(turnDuration),
            results: nil,
            version: 0
        )

        state.openFirstBettingRound(now: now)
        return state
    }

    private static func activeDealerIndex(preferred: Int, players: [Player]) -> Int {
        let preferred = normalizedSeat(preferred, playerCount: players.count)
        if players.isEmpty || players[preferred].canAct {
            return preferred
        }
        for offset in 1..<players.count {
            let candidate = (preferred + offset) % players.count
            if players[candidate].canAct {
                return candidate
            }
        }
        return preferred
    }

    private static func preparedPlayersForNewHand(_ input: [Player]) -> [Player] {
        var players = input
        for index in players.indices {
            players[index].bet = 0
            players[index].committed = 0
            players[index].holeCards = []
            players[index].lastActionBet = nil
            players[index].lastAction = nil
            players[index].status = statusForFreshHand(players[index])
        }
        return players
    }

    private static func statusForFreshHand(_ player: Player) -> PlayerStatus {
        if player.isEligibleForNextHand { return .active }
        return player.hasLeft ? .sittingOut : .eliminated
    }

    private static func dealOrder(players: [Player], dealerIndex: Int) -> [Int] {
        guard !players.isEmpty else { return [] }
        var order: [Int] = []
        for offset in 1...players.count {
            let seat = (dealerIndex + offset) % players.count
            if players[seat].canAct { order.append(seat) }
        }
        return order
    }

    private static func dealHoleCards(to players: inout [Player], deck: inout [Card],
                                      dealOrder: [Int]) {
        for _ in 0..<2 {
            for seatIndex in dealOrder {
                guard let card = deck.dealTopIfAvailable() else { return }
                players[seatIndex].holeCards.append(card)
            }
        }
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

        let nextDealerOriginalIndex = nextOriginalSeatAfterDealer(in: Set(eligibleOriginalIndices))
        guard let dealer = eligibleOriginalIndices.firstIndex(of: nextDealerOriginalIndex) else {
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

    private func nextOriginalSeatAfterDealer(in eligible: Set<Int>) -> Int {
        guard !players.isEmpty else { return dealerIndex }
        let dealerIndex = Self.normalizedSeat(dealerIndex, playerCount: players.count)
        for offset in 1...players.count {
            let candidate = (dealerIndex + offset) % players.count
            if eligible.contains(candidate) { return candidate }
        }
        return eligible.min() ?? dealerIndex
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
            let amount = (level - previous) * contributors.count
            let eligible = contributors.filter { players[$0].isContesting }
            let winners = winners(among: eligible, ranks: ranks)
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

    private func showdownResults(ranks: [Int: HandRank], winnings: [String: Int]) -> [HandResult] {
        players.indices.compactMap { index in
            guard players[index].isContesting,
                  let amount = winnings[players[index].id],
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
